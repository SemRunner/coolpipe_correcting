#encoding: utf-8
module Sketchup::CoolPipe
	######
	class CoolPipeTool                # Общий класс для всех инструментов Плагина CoolPipe
		include Math
		# Константы состояния инструмента:
		STATE_SELECT_FIRST_POINT  = 0 # Выбор первой точки
		STATE_SELECT_SECOND_POINT = 1 # Выбор второй точки
		STATE_SET_ANGLE           = 2 # Задание угла (вращение вокруг оси)
		STATE_SET_RADIUS_ANGLE    = 3 # Задание угла 2 (для отводов)
		ALTERNATIVE_DIAMETR       = 0 # Альтернативный диаметр в атрибутах коннектора
		ALTERNATIVE_STENKA        = 1 # Альтернативная толщина стенки в атрибутах коннектора
		#$cp_segments          #Количество сегментов
		#$cp_elbowK            #Коэффициент построения радиуса отвода от его диаметра
		#$cp_elbowPlotnost     #Плотность материала для расчета массы отвода [г/см³]
		#$cp_vnGeom=true/false #Строить внутреннюю геометрию
		def initialize(param = nil)   # Инициализация инструмента, по умолчанию параметры не заданы
			super()
			if  param!=nil
				@param = param
			else
				@param = {}
			end
			@passive_color   = "blue"
			@active_color    = "green"
			@mx = 0; @my = 0
		end
		def deactivate(view);view.invalidate if @drawn;end
		def onCancel(flag, view);self.reset(view);end
		def get_connectorspoints(component,trans)  # РЕКУРСИВНАЯ ФУНКЦИЯ поиска точек коннекторов у объекта (ЕСЛИ КОННЕКТОР ЭТО КЛАСС Face)
			connectors = []
			component_class = component.class.to_s
			case component_class
				when "Sketchup::Group"
					component.entities.each{|entity|;connectors += get_connectorspoints(entity,trans)}
				when "Sketchup::ComponentInstance"
					component.definition.entities.each{|entity|;connectors += get_connectorspoints(entity,trans)}
				else
					attribute = component.get_attribute("CoolPipeComponent","Тип")
					if attribute=="Коннектор"
						bb = Geom::BoundingBox.new
						vertices = component.vertices
						vertices.each{|vertex|;bb = bb.add(vertex);}
						connectors << bb.center.transform!(trans)
					end
			end
			connectors.compact
			connectors
			end
		def transform_by_point(points)             # Трансформация точек относительно центра их расположения
			box=Geom::BoundingBox.new
			box.add(points)
			pp=box.center
			trans=Geom::Transformation.new(pp)
			trans.invert!
			return trans
			end
		def set_connector_point(point,vec,alt_dn = nil, alt_st = nil) # Добавляет атрибуты коннектора к точке
			vector_atr= "#{vec.x.to_f}|#{vec.y.to_f}|#{vec.z.to_f}"
			#puts "vec.length = #{vec.length}"
			#puts "vector_atr = #{vector_atr}"
			value = point.set_attribute "CoolPipeComponent","Коннектор",vector_atr  if point!=nil
			value = point.set_attribute "CoolPipeComponent","Альт_Диаметр",alt_dn   if alt_dn!=nil
			value = point.set_attribute "CoolPipeComponent","Альт_Стенка",alt_st    if alt_st!=nil
			value
		end
		def get_altDN_from_conector(connector)     # Возвращение в виде массива альтернативного диаметра и толщины стенки из коннектора
			alt_dn = connector.get_attribute("CoolPipeComponent","Альт_Диаметр")
			alt_st = connector.get_attribute("CoolPipeComponent","Альт_Стенка")
			rezult= [alt_dn,alt_st]
			rezult
			end
		def moveOBJ(group,pt,vec)                  # Перемещение объекта из начала координат в заданное место
			obj_zaxis=vec.reverse
			trans=Geom::Transformation.new(pt,obj_zaxis)
			group.transformation=trans
		end
		def cp_setattributes(attributes,component) # Установка атрибутов компоненту #(пока не применяется - не срабатывает)
			if (attributes!=nil) && (component!=nil)
				attributes.each_pair do |key,value|
					component.set_attribute "CoolPipeComponent",key.to_s,value.to_s if (attributes!=nil) && (component!=nil)
					#puts "set_attribute: #{key.to_s}=#{value.to_s}"
				end
			end
			end
		def where_connector(component,mx,my,view,trans)#Определяет место расположение коннекторов и вектор направления дальшейших дествий
			trans = component.transformation
			connectors = []
			origins = []
			attributes=[]
			alt_dns = []
			@layer = nil
			@material = nil
			@connector_vector = nil
			@connector_point = nil
			@flange_component = false
			type = component.get_attribute("CoolPipeComponent","Тип")
			#@param[:Dнар] = component.get_attribute("CoolPipeComponent","Dнар")
			#@param[:стенка] = component.get_attribute("CoolPipeComponent","стенка")
			connectors = Sketchup::CoolPipe::cp_get_connectors_arr(component) #Находит все коннекторы объекта
			if connectors.length>0
				screen_connectors = connectors.collect{|connector|view.screen_coords(connector.position.transform!(trans))} #Экранные координаты коннекторов (точки)
				screen_connectors = screen_connectors.collect{|connector|Geom::Point3d.new(connector.x,connector.y,0)}
				mouse_on_screen  = Geom::Point3d.new(mx,my,0)#Место расположение указателя мыши на экране
				vec_mousetoconnectors = screen_connectors.collect{|connector|mouse_on_screen.vector_to connector}
				lengths_vec = vec_mousetoconnectors.collect{|vec|vec.length}
				minlength = lengths_vec.min
				index1 = lengths_vec.index(minlength)
				@connector_point = connectors[index1].position.transform!(trans)
				@layer = component.layer
				@material = component.material
				case type
					when "Труба"
						@connector_vector = connectors[0].position-connectors[1].position if index1==0
						@connector_vector = connectors[1].position-connectors[0].position if index1==1
						@connector_vector = @connector_vector.transform!(trans)
					when "Отвод"
						# Поиск точки ActualPointRotate
							pointrotate = Sketchup::CoolPipe::getFirstElementFromAttribue(component,"ActualPointRotate")
							pointrotate = pointrotate.position.transform!(trans) if pointrotate!=nil
						# Поиск точки CenterCenterLine
							vershinapt = Sketchup::CoolPipe::getFirstElementFromAttribue(component,"CenterCenterLine")
							vershinapt = vershinapt.position.transform!(trans) if vershinapt!=nil
						vec1 = pointrotate.vector_to connectors[0].position.transform!(trans) #Вектор к первому коннектору
						vec2 = pointrotate.vector_to connectors[1].position.transform!(trans) #Вектор ко второму коннектору
						degrees180=false
						degrees180=true if (vec1.parallel? vec2) #Если отвод 180 градусов используется вектор к вершине отвода
						vec2 = pointrotate.vector_to vershinapt if degrees180==true
						vec3 = vec1.cross vec2 #Вектор перпендикулярный плоскости образованной предыдущими веторами
						vec4 = vec3.cross vec1 #Вектор для первого коннектора
						vec5 = vec3.cross vec2 #Вектор для второго коннектора
						vec5 = vershinapt.vector_to pointrotate if degrees180==true
						@connector_vector = vec4.reverse! if index1==0
						@connector_vector = vec5          if index1==1
					when "Переход"
						@connector_vector = connectors[0].position.transform!(trans)-connectors[1].position.transform!(trans) if index1==0
						@connector_vector = connectors[1].position.transform!(trans)-connectors[0].position.transform!(trans) if index1==1
						alt_info = get_altDN_from_conector(connectors[index1]) #Поиск дополнительной информации по коннекторам (дополнительный диаметр для перехода или тройника)
						@alt_dn  = alt_info[ALTERNATIVE_DIAMETR]
						@alt_st  = alt_info[ALTERNATIVE_STENKA]
					when "Тройник"
						alt_info = get_altDN_from_conector(connectors[index1])
						@alt_dn  = alt_info[ALTERNATIVE_DIAMETR]
						@alt_st  = alt_info[ALTERNATIVE_STENKA]
						pt1 = connectors[0].position.transform!(trans)
						pt2 = connectors[1].position.transform!(trans)
						pt3 = connectors[2].position.transform!(trans)
						@connector_vector = pt1-pt2 if index1==0
						@connector_vector = pt2-pt1 if index1==1
						if index1==2
							pt4 = Geom::Point3d.linear_combination 0.5, pt1, 0.5, pt2
							@connector_vector = pt4.vector_to pt3
							#vec_atr = connectors[2].get_attribute("CoolPipeComponent","Коннектор")
							#arr = vec_atr.split("|").collect{|elem|elem.gsub("mm","").to_f}
							#@connector_vector = (Geom::Vector3d.new(arr[0].mm,arr[1].mm,arr[2].mm))
						end
					when "Заглушка"
						alt_info = get_altDN_from_conector(connectors[index1])
						@alt_dn  = alt_info[ALTERNATIVE_DIAMETR]
						@alt_st  = alt_info[ALTERNATIVE_STENKA]
						vec_atr = connectors[0].get_attribute("CoolPipeComponent","Коннектор")
						arr = vec_atr.split("|").collect{|elem|elem.gsub("mm","").to_f}
						@connector_vector = (Geom::Vector3d.new(arr[0].mm,arr[1].mm,arr[2].mm)).transform!(trans)
					when "Фланец"
						@connector_vector = connectors[0].position.transform!(trans)-connectors[1].position.transform!(trans) if index1==0
						@connector_vector = connectors[1].position.transform!(trans)-connectors[0].position.transform!(trans) if index1==1
						@flange_component = true
				end
				end
			end #def where_connector(component,mx,my,view,trans)
		def get_angle_mouse_connector(flags,x,y,view)#Для рисования отвода и тройника, поиск угла для направляющей поворота элемента
			########
			#1. Выбрать 4 точки окружности (панели вращения) - получить массив этих точек (соответствуют началам квадрантов)
			#2. Спроецировать на экран точки по п.1,точку центра этой окружности, и точку мыши
			#3. Вычислить 5(1+4) векторов до мыши и до опорных точек квадрантов
			#4. Вычислить 4 угла по векторам: квадранты и мышь + сортировка по возрастанию
			#5. Найти 2 первых индекса минимальных углов - это будут те координаты квадрантов между которыми находится мышь
			#6. Определим квадрант расположения указателя мыши по ближайшим двум точкам и вычисляем реальный угол от 0-359 градусов
			@ip2.pick view, x, y
			@sel_angle_panel = generate_arc(@param[:Dнар],0,360,5).collect{|pt|;pt.transform(@transform_point)} #Окружность для рисования панели выбора градуса
			@mouse_point = Geom::Point3d.new(x,y,0) if (x!=nil)&&(y!=nil) #Мышь на экране
			if @mouse_point!=nil
				@connectoronscreen = view.screen_coords @connector_point #Коннектор в координатах экрана
				vec_connect2mouse = @connectoronscreen.vector_to @mouse_point #Вектор от коннектора к мыши
				@point_anglevec = @connectoronscreen.offset vec_connect2mouse,150 if vec_connect2mouse.length>0 #Смещение коннектора по вектору для получения второй точки направляющей вращения
				if @sel_angle_panel.length>0
					control_pts = [@sel_angle_panel[0],@sel_angle_panel[18],@sel_angle_panel[36],@sel_angle_panel[54]] #1
					screen_control_pts = [view.screen_coords(control_pts[0]),
											view.screen_coords(control_pts[1]),
											view.screen_coords(control_pts[2]),
											view.screen_coords(control_pts[3])] #2
					screen_center_circle = @connectoronscreen#2
					screen_mouse = Geom::Point3d.new x,y,0 #2
					vec_quadrants = [screen_center_circle.vector_to(screen_control_pts[0]),
									screen_center_circle.vector_to(screen_control_pts[1]),
									screen_center_circle.vector_to(screen_control_pts[2]),
									screen_center_circle.vector_to(screen_control_pts[3])] #3
					vec_centertomouse = screen_center_circle.vector_to screen_mouse #3
					vec_angles_screen = [vec_centertomouse.angle_between(vec_quadrants[0]),
										vec_centertomouse.angle_between(vec_quadrants[1]),
										vec_centertomouse.angle_between(vec_quadrants[2]),
										vec_centertomouse.angle_between(vec_quadrants[3])] #4
					sort_vec_angles = vec_angles_screen.sort #4
					min_index1 = vec_angles_screen.index(sort_vec_angles[0]) #5
					min_index2 = vec_angles_screen.index(sort_vec_angles[1]) #5
					angle = 0
					if    (min_index1==0)&&(min_index2==1)  #6
							angle = PI/2-sort_vec_angles[min_index1]
					elsif (min_index1==1)&&(min_index2==0)
							angle = sort_vec_angles[min_index2]
					elsif (min_index1==1)&&(min_index2==2)
							angle = 2*PI-(PI/2-sort_vec_angles[min_index1])
					elsif (min_index1==2)&&(min_index2==1)
							angle = 2*PI-sort_vec_angles[min_index2]
					elsif (min_index1==2)&&(min_index2==3)
							angle = 2*PI-sort_vec_angles[min_index1]
					elsif (min_index1==3)&&(min_index2==2)
								angle = PI/2+sort_vec_angles[min_index2]
					elsif (min_index1==3)&&(min_index2==0)
							angle = sort_vec_angles[min_index1]
					elsif (min_index1==0)&&(min_index2==3)
							angle = PI/2+sort_vec_angles[min_index1]
					end#6
				end
			end
			angle
		end
		def onKeyDown(key, repeat, flags, view)    #обработчик событий нажатий клавиш на клавиатуре
			if (key.to_s=="27") or (key.to_s=="17") #ESC or Del
				@selection.clear if @selection!=nil
				Sketchup.active_model.select_tool(nil)
			end
			end
		def generate_arc(diam,start_gradus,end_gradus,step)#Генерация точек дуги в центре координат с параметрами: диаметр, градусы (начало,, шаг градусов
			circle = []
			start_gradus.step(end_gradus,step){|angle|          #Построение 3-х окружностей в центре координат
				x = (sin(angle.degrees)*diam.to_f).mm
				y = (cos(angle.degrees)*diam.to_f).mm
				circle << Geom::Point3d.new(x,y,0)
			}
			return circle
			end
		def setLayer(layerName,component)          #Установка слоя на компонент
			layer = model.layers.add(layerName)
			component.layer = layer
		end
		def setactivLayer(layerName)               #Установка активного слоя c проверкой существующих, возвращает предыдущий слой
			if layerName!=nil
				layerName=layerName.name if layerName.class==Sketchup::Layer
				if layerName!=""
					if (layerName!="0") #если нужно присвоить слой
						model = Sketchup.active_model
						layers = model.layers
						activlayer = layers[layerName].to_s
						if (activlayer!="")
							activlayer = layerName
						else
							new_layer = layers.add layerName
							name = new_layer.name = layerName
							activlayer = layerName
						end
						prevactivlayer = model.active_layer
						model.active_layer = activlayer
						return prevactivlayer
					end
				end
			end
		end
		def cp_setmaterialonface(param,face)       #Устанавливает материал к face если материал пустой то White на переднюю и заднюю грани
			if (param[:Материал]!="") or (param[:Материал]!=nil)
				model = Sketchup.active_model
				materials = model.materials
				addmaterial = true
				materials.each {|material|;addmaterial = false if material.name==param[:Материал];}
				materials.add param[:Материал] if addmaterial
				face.material = param[:Материал]
				face.back_material = param[:Материал]
			else
				face.material ="white"
				face.back_material = "white"
			end
		end
	end #class CoolPipeTool
	class ToolDrawElement<CoolPipeTool       #Общий класс для всех инструментов отрисовки элементов
		def initialize(param = nil)          # Инициализация инструмента, по умолчанию параметры не заданы
			super(param) #наследование метода из класса CoolPipeTool
			@ip  = nil
			@ip1 = nil
			@ip2 = nil
			@ip3 = nil
			@ip4 = nil
			@anchorAnglesMenu = []
		end
		def activate                         # Активация тула
			@ip  = Sketchup::InputPoint.new
			@ip1 = Sketchup::InputPoint.new
			@ip2 = Sketchup::InputPoint.new
			@ip3 = Sketchup::InputPoint.new
			@ip4 = Sketchup::InputPoint.new
			@drawconnector=false
			self.reset(nil)
		end
		def reset(view)                      # Сброс тула
			@state = STATE_SELECT_FIRST_POINT
			@ip.clear  if @ip!=nil
			@ip1.clear if @ip1!=nil
			@ip2.clear if @ip2!=nil
			@ip3.clear if @ip3!=nil
			@ip4.clear if @ip4!=nil
			view.invalidate if view!=nil
		end
		def getExtents                       # Указывает Sketchup границы рисования для View
			bounds = Sketchup.active_model.bounds
			bounds.add @ip1.position if @ip1.valid?
			bounds.add @ip2.position if @ip2.valid?
			bounds.add @ip3.position if @ip3.valid?
			bounds.add @ip4.position if @ip4.valid?
			return bounds
		end
		def onKeyDown(key, repeat, flags, view)#Обработка нажатий клави на клавиатуре при нажатии
			if( key == CONSTRAIN_MODIFIER_KEY && repeat == 1 )
				@shift_down_time = Time.now
				if( view.inference_locked? )
					view.lock_inference
				elsif( @state == STATE_SELECT_FIRST_POINT && @ip2.valid? )
					view.lock_inference @ip2
				elsif( @state == STATE_SELECT_SECOND_POINT && @ip3.valid? )
					view.lock_inference @ip3, @ip2
				end
			end
			super(key, repeat, flags, view)
		end
		def draw_array_circlepts(array_circlepts,view) #Отрисовка массива окружностей
			pre_pts = nil
			if array_circlepts!=nil
				if array_circlepts.length>0
					array_circlepts.each {|pts|
						view.line_stipple = ""
						view=view.draw GL_LINE_LOOP, pts #отрисовка окружностей
						if pre_pts!=nil
							for i in 0..(pts.length-1)
								view.line_stipple = "."
								view=view.draw GL_LINE_LOOP, pts[i],pre_pts[i] #отрисовка соединений окружностей
							end
						end
						pre_pts = pts
					}
				end
			end
		end
		def addAnchorAngle(view,point,vector,x,y,angle,type="circle") #Добавление пункта меню якорного угла
			item=[]
			circle = generate_arc(@param[:Dнар].to_f/18,0,360,30) #диаметр = 5мм, шаг 30 градусов (12 сегментов)
			trans = Geom::Transformation.new point,vector
			circle = circle.collect{|pt|;pt.transform(trans)}
			item.push(circle)
			item.push(angle) #Содержит значение якорного угла
			@anchorAnglesMenu.push(item)
			@anchorAnglesMenu.uniq
			if isAnchorAngleActive?(view,item,x,y)
				view.drawing_color = @active_color
			else
				view.drawing_color = @passive_color
			end
			view=view.draw GL_LINE_LOOP, circle #Отрисовка пункта меню якорного градуса
		end
		def getAnchorAngle(view,x,y) #Получение якорного угла по указателю мыши
			angle = nil #возвращается если нет активных якорных углов
			@anchorAnglesMenu.each {|item|
				circle = item[0]
				angle = item[1] if isAnchorAngleActive?(view,item,x,y)
			}
			angle
		end
		def isAnchorAngleActive?(view,item,x,y) #Проверяет активность комманды (якорного угла)
			rezult=false
			if @anchorAnglesMenu!=nil
				circle = item[0]
				bounds = Geom::BoundingBox.new
				circle.each{|pt|;bounds.add(pt)}
				corners=[];screen=[];x_arr=[];y_arr=[]
				for i in 0..7;corners<<bounds.corner(i);end
				for i in 0..7;screen<<view.screen_coords(corners[i]);end
				for i in 0..7;x_arr<<screen[i].x;y_arr<<screen[i].y;end
				x1 = x_arr.min.to_i; x2 = x_arr.max.to_i
				y1 = y_arr.min.to_i; y2 = y_arr.max.to_i
				rezult = true if (x>=x1) && (x<=x2) && (y>=y1) && (y<=y2)
			end
			rezult
		end
		################################################
		################################################
	end #class ToolDrawElement
	class ToolEditElement<CoolPipeTool       #Общий класс для всех инструментов редактирования элементов
		def initialize(name,component,selection) #Инициация инструментов редактирования
			@component_pipe = component
			@selection = selection
			@vector_pipe    = nil #вектор трубы
			@name_connect    = ""
			@passive_color   = "Bisque"
			@active_color    = "LightGreen"
			@uklon_leftmenu  = false
			@uklon_rightmenu = false
			@drawn           = true
			@x = 0
			@y = 0
			@active_command = ""
			@name           = name
			@screen_menu    = []
			@length = nil
			reset(nil)
			@cp_change_pipe_tool = self
			@cp_change_reducer_tool = self
			@cp_edit_pipe_enable = false
			@view = nil
			super()
		end
		def activate                             #Активация тула
			@drawn = true
			self.reset(nil)
		end
		def reset(view)
			if( view )
				view.tooltip = nil
				view.invalidate if @drawn
			end
			@drawn = false
			@dragging = false
			@active_command = ""
			@screen_menu    = []
			@length = nil
			@pt_begin = nil
			@pt_center= nil
			@pt_end   = nil
		end
		def onCancel(flag, view)
			self.reset(view)
		end
		def enableVCB?
			return false
		end
		def add_menu_item(view,x,y,width,height,text,command) #Добавляет кнопку с текстом
			item=[]
			point11 = Geom::Point3d.new x,y,0
			point12 = Geom::Point3d.new x+width,y,0
			point13 = Geom::Point3d.new x+width,y+height,0
			point14 = Geom::Point3d.new x,y+height,0
			if (@x>=x) && (@x<=x+width) && (@y>=y) && (@y<=y+height)
				view.drawing_color = @active_color
			else
				view.drawing_color = @passive_color
			end
			status2 = view.draw2d GL_QUADS, point11, point12, point13, point14
			point15 = Geom::Point3d.new x+3,y,0
			status1 = view.draw_text point15, text
			item.push(point11) #0
			item.push(point12) #1
			item.push(point13) #2
			item.push(point14) #3
			item.push(text)    #4
			item.push(command) #5
			@screen_menu.push(item)
		end
		def get_menu_command(x,y) #Получение команд от нарисованных кнопок
			command = ""
			@screen_menu.each {|item|
				x1 = item[0].x
				x2 = item[1].x
				y1 = item[0].y
				y2 = item[2].y
				command = item[5] if (x>=x1) && (x<=x2) && (y>=y1) && (y<=y2)
			}
			@active_command = command
		end
		def emulselection(obj)# Эмуляция выбора объека (после перерисовки)
			 @component_pipe = obj
			 status = @selection.add @component_pipe
			 Sketchup.active_model.select_tool ToolEditPipe.new(@name,@component_pipe,@selection)
		end
		def onKeyDown(key, repeat, flags, view)
			if (key.to_s=="27") or (key.to_s=="17") #ESC or Del
				@selection.clear
				Sketchup.active_model.select_tool(nil)
			end
		end
		def onMouseMove(flags, x, y, view)
			@view = view
			@x = x
			@y = y
			if @component_pipe!=nil
				@name = @component_pipe.get_attribute("CoolPipeComponent","Имя")
			end
		end
		def onLButtonDown(flags, x, y, view)
			get_menu_command(x,y)
			if @active_command!=""
				@attributes = nil
				getparams_frompipe
				@attributes[:Точка_начала]=nil
				@attributes[:Точка_конца] =nil
				on_menu_click(@active_command,view)
				redrawpipe(view)
			else
				@selection.clear
				Sketchup.active_model.select_tool(nil)
				ph = view.pick_helper
				ph.do_pick x,y
				best = ph.best_picked
				if best!=nil
				model = Sketchup.active_model
				selection = model.selection
				status = selection.add best
				end
			end
			invalidated_view = view.invalidate
		end
	end #class ToolEditElement
	########################################################################################
	# Отрисовка элементов
	########################################################################################
	class ToolDrawPipe    < ToolDrawElement  #Инструмент отрисовки трубопровода
		def initialize(param = nil)            #Инициализация инструмента, по умолчанию параметры не заданы
			super(param) #наследование метода из класса ToolDrawElement
			@param = param
			Sketchup::set_status_text($coolpipe_langDriver["Указать начало трубопровода"], SB_PROMPT)
		end
		def onUserText(text, view)             #Ввод пользовательского текста (используется для указания длины отрезка)
			return if not @state == STATE_SELECT_SECOND_POINT
			return if not @ip2.valid?
			begin
				value = text.to_l
			rescue
				UI.beep
				puts($coolpipe_langDriver["Не могу конвертировать в длину "]+text)
				value = nil
				Sketchup::set_status_text "", SB_VCB_VALUE
			end
			return if !value
			pt1 = @ip2.position
			vec = @ip3.position - pt1
			if( vec.length == 0.0 )
				UI.beep
				return
			end
			vec.length = value
			pt2 = pt1 + vec
			if (@zaxes!=nil) && (@pt_startpipe!=nil)
				begin
				pt1=@pt_startpipe
				vec=pt2 - pt1
				pt2=pt1.offset @zaxes,value
				rescue
				UI.beep
				end
			end
			if (@connector_vector!=nil)and(@connector_point!=nil)
				pt1 = @connector_point
				pt2 = pt1.offset @connector_vector, value
			end
			@param[:Точка_начала]=pt1
			@param[:Точка_конца]=pt2
			cp_create_pipe_geometry(@param,@param[:Точка_начала],@param[:Точка_конца],@param[:view])
			Sketchup.active_model.select_tool nil
		end
		def enableVCB?                         #Разрешение/Запрещение пользовательского ввода
			return false if @state == STATE_SELECT_FIRST_POINT   #запрещаем пользовательский ввод
			return true  if @state == STATE_SELECT_SECOND_POINT  #разрешаем пользовательский ввод
		end
		def onMouseMove(flags, x, y, view)     #Обработчик перемещения мыши
			@param[:view]=view
			#@drawconnector = false
			case @state
				when STATE_SELECT_FIRST_POINT
					#если курсор расположен над коннектором coolpipe - то нужно отобразить коннектор
					ph = view.pick_helper
					ph.do_pick x,y
					component = ph.best_picked
					@ip1.pick view, x, y
					view.tooltip = @ip1.tooltip #if(@ip1.valid?) #отслеживание привязок по сторонней геометрии
					if Sketchup::CoolPipe::cp_iscpcomponent?(component)  #Указатель мыши над компонентом CoolPipeComponent
						#bbox = component.local_bounds
						trans = component.transformation
						@connector_point = nil
						@connector_vector= nil
						@drawconnector=false
						where_connector(component,x,y,view,trans)
						if @connector_vector!=nil
							@drawconnector=true
							@pt_startpipe = @connector_point
						end
					else
						@drawconnector=false
					end
					if( @ip1!=@ip2)
						@ip2.copy! @ip1
						view.tooltip = @ip2.tooltip
						view.invalidate if(@ip1.display? or @ip2.display? )
					end
				when STATE_SELECT_SECOND_POINT
					@ip3.pick view, x, y, @ip2
					@ip4.pick view, x, y
					view.tooltip = @ip4.tooltip if( @ip4.valid? ) #отслеживание привязок по сторонней геометрии
					length = 0
					if( @ip3.valid? )
						length = @ip2.position.distance(@ip3.position)
						Sketchup::set_status_text length.to_s, SB_VCB_VALUE
					end
					if (@connector_vector!=nil)and(length>0)
						point = @ip2.position.offset @connector_vector,length
						@ip3 = Sketchup::InputPoint.new(point)
					end
			end
			view.invalidate
		end #def onMouseMove(flags, x, y, view)
        def onLButtonDown(flags, x, y, view)   #Обработчик нажатия клавиши мыши
			case @state
				when STATE_SELECT_FIRST_POINT
					@ip2.pick view, x, y
					if( @ip2.valid? )
						@state = STATE_SELECT_SECOND_POINT
						Sketchup::set_status_text($coolpipe_langDriver["Указать конец трубопровода"], SB_PROMPT)
						@xdown = x
						@ydown = y
					end
					if @pt_startpipe!=nil
						@xdown = @pt_startpipe.x
						@ydown = @pt_startpipe.y
					end
				when STATE_SELECT_SECOND_POINT
					if( @ip3.valid? )
						cp_create_pipe_geometry(@param,@param[:Точка_начала],@param[:Точка_конца],@param[:view])
						Sketchup.active_model.select_tool nil
					end
			end
			view.lock_inference
		end #def onLButtonDown(flags, x, y, view)
		def drawIpIfdisplay(ip,view)
			ip.draw(view) if(ip.display?)
		end
		def draw(view)                         #Отрисовка коннекторов и сетки
			drawIpIfdisplay(@ip2,view)
			drawIpIfdisplay(@ip3,view)
			drawIpIfdisplay(@ip4,view)
			if( @ip2.valid? )&&(@ip3.valid?)&&(@ip4.valid?)
				view.line_stipple = ""
				if (@zaxes!=nil) && (@pt_startpipe!=nil)
					view.drawing_color = "black" #Если труба чертится от коннектора - то ее цвет черный
				else
					view.set_color_from_line(@ip2, @ip3) #если труба произвольная - то настройки цвета от SketchUp
				end
				if	(@drawconnector==true)
					p1 = @ip4.position #Указатель мыши
					p2 = @connector_point.offset(@connector_vector,(p1-@connector_point).length) #Смещение коннектора по вектору коннектора на расстояние до мыши
					line = [@connector_point,p2] #линия вектор
					p3 = p1.project_to_line line #Проекция мыши на вектор от коннектора (прямоугольный треугольник)
					draw_geometry(@connector_point, p3, view)
					view.drawing_color = "black"
					view.line_stipple = "."
					view.draw_line(@connector_point, p1)
					view.draw_line(p1, p3)
				elsif @drawconnector==false
					draw_geometry(@ip2.position, @ip3.position, view)
				end
			end
			if (@connector_point!=nil)&&(@connector_vector!=nil)
				view.draw_points  @connector_point, 9, 1, "red"
				view.drawing_color = "lightgreen" #вектор направления присоединения зеленого цвета
				view.line_stipple = ""
				pts = [@connector_point,(@connector_point.offset(@connector_vector,10))]
				#puts "pts=#{pts}"
				view.draw(GL_LINES, pts) if pts!=nil #показываем вектор от коннектора светлозеленным цветом
			end
			if @pt_startpipe!=nil
				view.draw_points @pt_startpipe, 10, 2, "Magenta" #коннектор для присоединения трубопровода
			end
		end #def draw(view)
		def draw_geometry(pt1, pt2, view)      #Рисует сетку трубы
			if (@zaxes!=nil) && (@pt_startpipe!=nil)
				begin
					pt1=@pt_startpipe
					vec=pt2 - pt1
					length=vec.length
					pt2=pt1.offset @zaxes,length
				rescue
					UI.beep
				end
			end
			@param[:Точка_начала]=pt1
			@param[:Точка_конца]=pt2
			view.draw_line(pt1, pt2)
			vec = pt2 - pt1
			r = @param[:Dнар].to_f.mm/2
			i = 0
			pt_start = []
			pt_end = []
			if vec.length>0
				0.step(360,360/$cp_segments) {|angle|
					x1 = r * Math.cos(angle*(Math::PI)/180)
					y1 = r * Math.sin(angle*(Math::PI)/180)
					z1 = 0
					pt_start[i] = [x1,y1,z1]
					i = i+1
				} #step
				t1=transform_by_point(pt_start)
				points=pt_start.collect {|p| p.transform(t1)}
				trans=Geom::Transformation.new(pt1,vec.reverse)
				points=points.collect {|p| p.transform(trans)}
				end_points=points.collect {|p| p.offset(vec)}
				view.draw(GL_LINE_STRIP, points)
				view.draw(GL_LINE_STRIP, end_points)
				0.step((points.length),1) {|i|
					view.draw_line(points[i], end_points[i])
				} #step
				view.draw_points  @ip4.position, 3, 1, "blue" if (@ip4.valid?)  #Отображение точки привязки
			end # if
		end #def draw_geometry(pt1, pt2, view)
		def cp_create_pipe_geometry(param,pt1,pt2,view) #Создание геометрии трубы в виде цилиндра
			attributes = cp_createpipeattributes(param) #Получаем список атрибутов для трубопровода
			radius1  = param[:Dнар].to_f.mm/2 #Результат - наружний радиус в дюймах
			radius2 = param[:Dнар].to_f.mm/2-param[:стенка].to_f.mm #Результат - внутренний радиус в дюймах
			prevlayer1 = setactivLayer(param[:Имя_слоя]) if param[:Имя_слоя]!=nil # Устанавливаем активный слой если задан в параметрах
			model = view.model
			model.start_operation "Создание объекта CoolPipe::Труба"
			vec = pt2 - pt1
			length = vec.length
			numstrTubes = 0
			remainderLengthPipe = 0
			#Добавка в v1.4 (2018)
			if param[:Заданпрямуч]=="true"
				numstrTubes = (length.inch / param[:Длинпрямуч].to_f.mm).to_i #Количество отрезков ограниченных длиной заданного прямого участка
				puts $coolpipe_langDriver["Количество отрезков трубы с заданным прямым участком составляет"]+" #{numstrTubes} шт x [#{param[:Длинпрямуч]} мм]"
				remainderLengthPipe = (length - numstrTubes*param[:Длинпрямуч].to_f.mm).inch #Остаток трубы не входящий в прямой участок
				if remainderLengthPipe>0
				 puts $coolpipe_langDriver["Плюс дополнительный учаток длиной"]+" #{remainderLengthPipe}"
				end
			end
			#---------------------
			if (numstrTubes==0) and (remainderLengthPipe==0)
				component=generatePipe(model,param,attributes,pt1,pt2,view,length,radius1,radius2,vec) #нормальное поведение, просто рисует трубу от точки А в точку Б
			else
				remainderneed = 0
				ppt1 = pt1.clone
				ppt2 = pt1.offset(vec,param[:Длинпрямуч].to_f.mm)
				for i in 1..(numstrTubes)
					component=generatePipe(model,param,attributes,ppt1,ppt2,view,param[:Длинпрямуч].to_f.mm,radius1,radius2,vec) #рисуем прямые участки со смещением по вектору
					ppt1 = ppt2.clone
					ppt2 = ppt2.offset(vec,param[:Длинпрямуч].to_f.mm)
				end
				if remainderLengthPipe>0
					component=generatePipe(model,param,attributes,ppt1,ppt2,view,remainderLengthPipe,radius1,radius2,vec) #рисуем отстаточный участок (который не вошел в прямые участки)
				end
			end
			setactivLayer(prevlayer1) if prevlayer1!=nil #Восстанавливаем исходный слой
			model.commit_operation
			component
		end
		#---------------------
		#Добавка в v1.4(2018)
		def generatePipe(model,param,attributes,pt1,pt2,view,length,radius1,radius2,vec)
			entities = model.active_entities
			groupglob=entities.add_group
			entities = groupglob.entities
			group=entities.add_group
			entities = group.entities
			component=groupglob.to_component
			name = param[:Имя]
			component.name = name
			component.definition.name=name
			ptstart = [0,0,0]
			ptend   = [0,0,-length]
			vector = Geom::Vector3d.new 0,0,-1
			connector_pts = []
			connector_pts << point1=entities.add_cpoint(ptstart)
			connector_pts << point2=entities.add_cpoint(ptend)
			vecbegin2end = pt1.vector_to pt2
			vecend2begin = pt2.vector_to pt1
			set_connector_point(point1,vecbegin2end)
			set_connector_point(point2,vecend2begin)
			line=entities.add_line ptstart, ptend #--- чертим ось
			if $cp_vnGeom #Строить внутреннюю геометрию
				circle1 = entities.add_circle ptstart, vector, radius1, param[:Сегментов]
				circle2 = entities.add_circle ptstart, vector, radius2, param[:Сегментов]
				face2 = entities.add_face circle2
				face1 = entities.add_face circle1
				face2.erase!
				face1.pushpull length
			else
				circle = entities.add_circle ptstart, vector, radius1, param[:Сегментов]
				face1 = entities.add_face circle
				normal = face1.normal
				length = -length if((normal % vector) < 0.0 )
				face1.pushpull length
			end
			if (param[:Заданпрямуч]=="true") and (param[:Учетвштуках]=="true")
				name = param[:Имя]#+" L=#{length.inch}"
				param[:L=]=length.inch.to_mm.round
				attributes[:L=]=param[:L=]
				#attributes[:Имя] = name
				component.name = name
				component.definition.name=name
				attributes[:масса] = param[:масса]
				attributes[:масса] = ((((attributes[:масса].to_f*(length.inch.to_mm/1000))*100).to_i.to_f)/100).to_s
			end
			behavior = component.definition.behavior #Для ограничения вариантов масштабирования объекта
			mask = (1<<0)+(1<<1)+(0<<2)+(1<<3)+(1<<4)+(1<<5)+(1<<6) #в десятичной записи 123 # Разрешаем только синюю ось Z
			behavior.no_scale_mask = mask #Применяем маску
			moveOBJ(component,pt1,vec)
			#puts attributes
			cp_setattributes(attributes,component) #Устанавливаем атрибуты только что созданному объекту
			component.material = param[:Материал] if param[:Материал]!=nil
			if attributes[:L=]==nil
				puts $coolpipe_langDriver["Начерчена: "]+"#{name}"
			else
				puts $coolpipe_langDriver["Начерчена: "]+"#{name} L=#{attributes[:L=]} мм"
			end
			component #Возвращает ссылку на созданный компонент
		end
		#---------------------
		def cp_createpipeattributes(param)     #создает список атрибутов для Трубы
			attributes={}
			if param!=nil
			attributes={:Тип         => param[:Тип],          #Тип компонента: труба
						:Имя            => param[:Имя],          #Наименование трубы для спецификации
						:ЕдИзм          => param[:ЕдИзм],        #Единица измерения для спецификации
						:масса          => param[:масса],        #Масса единицы для спецификации
						:Dнар           => param[:Dнар],         #Диаметр трубопровода наружний
						:стенка         => param[:стенка],       #Толщина стенки трубопровода
						:ГОСТ           => param[:ГОСТ],         #Нормативный документ (из базы)
						:Теплоизоляция  => param[:Теплоизоляция],#Толщина теплоизоляции, если нет то 0
						:Материал       => param[:Материал],     #Материал трубопровода (собственный цвет из настроек слоев)-если нет то 0
						:Заданпрямуч    => param[:Заданпрямуч],  #Флаг установки прямого участка трубопровода
						:Учетвштуках    => param[:Учетвштуках],  #Флаг требующий подсчет трубопровода в штуках
						:Длинпрямуч		 => param[:Длинпрямуч],   #Длина прямого участка #-добавка версии 1.4(2018)
						:L=				 => param[:L=],           #Длина данного участка трубопровода #-добавка версии 1.4.1(2018)
						:Стандартный_элемент =>"true"				  #элемент является стандартным #-добавка версии 1.4.1(2018)
						}
			end
			attributes
		end
	end #class ToolDrawPipe < ToolDrawElement
	######
	class ToolDrawElbow   < ToolDrawElement  #Инструмент отрисовки отвода
		def initialize(param = nil)          # Инициализация инструмента, по умолчанию параметры не заданы
			super(param)     #наследование метода из класса ToolDrawElement
            @angle_grad = 90 #Значение по умолчанию
        end

        def reset(view)                                  #Сброс настроек
			super(view)
			Sketchup::set_status_text($coolpipe_langDriver["Указать место расположения отвода"], SB_PROMPT)
			@drawn = false
			@connector_vector=nil
			@draw_elbow_pts = []
			@user_change_angle = false
			@user_change_radius_angle=false
		end
        def getExtents                                   #Указывает Sketchup границы рисования для View
			bounds = Sketchup.active_model.bounds
			@draw_elbow_pts.each{|dots|;dots.each{|pt|;bounds.add(pt)}} if @draw_elbow_pts!=nil
			@angle_panel_dots.each{|pt|;bounds.add(pt)} if @angle_panel_dots!=nil
			return bounds
		end
        def enableVCB?                                   #Разрешение/Запрещение пользовательского ввода
			return false if @state == STATE_SELECT_FIRST_POINT   #запрещаем пользовательский ввод
			return true  if @state == STATE_SET_ANGLE            #разрешаем пользовательский ввод
			return true  if @state == STATE_SET_RADIUS_ANGLE     #разрешаем пользовательский ввод
		end
		def onMouseMove(flags, x, y, view)               #Событие возникает при перемещении указателя мыши
			@param[:view]=view
			view.model.selection.clear #Если что-то выделено - снять выделение
			case @state
				when STATE_SELECT_FIRST_POINT
					onMouseMove_StateSelectFirstPoint(flags, x, y, view)
				when STATE_SET_ANGLE
					onMouseMove_StateSetAngle(flags, x, y, view)
				when STATE_SET_RADIUS_ANGLE
					onMouseMove_State_Set_Radius_Angle(flags, x, y, view)
			end
			view.invalidate
			@mx = x; @my = y
		end
		def onMouseMove_StateSelectFirstPoint(flags, x, y, view)   #Обработчик движения мыши при выборе точки расположения отвода (перемещение сетки)
			@ip.pick view, x, y
			ph = view.pick_helper
			ph.do_pick x,y
			component = ph.best_picked
			if component!=nil
                if Sketchup::CoolPipe::cp_iscpcomponent?(component)  # Указатель мыши над компонентом CoolPipeComponent
					create_elbow_param(ph,x,y,view)
					@drawconnector=true
					trans = component.transformation
					where_connector(component,x,y,view,trans)
					if (@connector_vector!=nil)and(@connector_point!=nil)
						@transform_point = Geom::Transformation.new @connector_point,@connector_vector
						@draw_elbow_pts = @elbow_dots.collect{|dots|;dots.collect{|pt|;pt.transform(@transform_point)}} if @elbow_dots!=nil #Для рисования сетки отвода
						@connector_point = (Geom::Point3d.new).transform(@transform_point)
						@elbow_vector = (Geom::Vector3d.new 1,0,0).transform(@transform_point)
						@elbow_basevec= (Geom::Vector3d.new 0,0,1).transform(@transform_point)
						@elbow_direct_din = @elbow_direct.collect {|pt|;pt.transform(@transform_point)} if @elbow_direct!=nil
						@actual_point_rotate = @point_rotate.transform(@transform_point) if @point_rotate!=nil #Точка вокруг которой рисуется отвод
					end
				else
					@connector_vector = nil
					@connector_point = nil
					@drawconnector = false
				end
			end
		end
        def onMouseMove_StateSetAngle(flags, x, y, view)           #Обработчик движения указателя мыши при выборе угла вращения вокруг точки вставки
			########
			#1. Выбрать 4 точки окружности (панели вращения) - получить массив этих точек (соответствуют началам квадрантов)
			#2. Спроецировать на экран точки по п.1,точку центра этой окружности, и точку мыши
			#3. Вычислить 5(1+4) векторов до мыши и до опорных точек квадрантов
			#4. Вычислить 4 угла по векторам: квадранты и мышь + сортировка по возрастанию
			#5. Найти 2 первых индекса минимальных углов - это будут те координаты квадрантов между которыми находится мышь
			#6. Определим квадрант расположения указателя мыши по ближайшим двум точкам и вычисляем реальный угол от 0-359 градусов
			#7. Повернем отображаемые сетки на найденный угол
            ########
			angle=get_angle_mouse_connector(flags, x, y, view) # 1 - 6
			anchorangle = getAnchorAngle(view,x,y)
			angle = anchorangle.degrees if anchorangle!=nil
			#puts "angle1=#{angle.radians.to_i}"
			@ip4.pick view, x, y
			view.tooltip = @ip4.tooltip if( @ip4.valid? ) #отслеживание привязок по сторонней геометрии
			if @user_change_angle == false
				angle_grad = (angle.radians).to_i
				str_angle = angle_grad.to_s
				Sketchup.vcb_value= str_angle + "°" #Печатаем найденный угол в зону контроля значения (в градусах)
				@rot_trans = Geom::Transformation.rotation @connector_point, @connector_vector, angle #7
				multi_trans = @rot_trans*@transform_point
				@elbow_direct_din = @elbow_direct.collect {|pt|;pt.transform(multi_trans)} #7
				@draw_elbow_pts = @elbow_dots.collect{|dots|;dots.collect{|dot|;dot.transform(multi_trans)}}#7
				@actual_point_rotate = @point_rotate.transform(multi_trans)
			end
		end
        def onMouseMove_State_Set_Radius_Angle(flags, x, y, view)  #Обработчик движения указателя мыши при выборе угла отвода (угол закругления от 0 до 180 градусов)
			if @user_change_radius_angle==false
				@ip3.pick view, x, y
				view.tooltip = @ip3.tooltip if( @ip3.valid? ) #отслеживание привязок по сторонней геометрии
                # dn = if ((@alt_dn==nil)or(@alt_dn==@param[:Dнар])) then @param[:Dнар].to_f else @alt_dn.to_f end
                dn = @param[:Dнар].to_f
                du = @param[:Du].to_f
				# radius = @param[:КоэфРадиусаОтИзгиба].to_f  #--!!-- что-то странное
                #point = Geom::Point3d.new(dn.mm*$cp_elbowK,0,0)
                # point = Geom::Point3d.new(du.mm*$cp_elbowK,0,0)
                point = Geom::Point3d.new(@param[:РадиусИзгиба].mm,0,0)
				move = Geom::Transformation.new point
				transformation =Geom::Transformation.rotation(point,[1,0,0],90.degrees)
                arc = generate_arc(3*du,-90,90,5)
				movearc = arc.collect{|pt|;pt.transform(move)}
				@angle_panel_dots = movearc.collect{|pt|;pt.transform(transformation).transform(@transform_point).transform(@rot_trans)} #Полуокружность для рисования панели выбора градуса поворота отвода
				########
				control_pt = @angle_panel_dots[0] #1
				screen_control_pts = view.screen_coords(control_pt) #2
				screen_center_circle = view.screen_coords(@actual_point_rotate)#2
				screen_mouse = Geom::Point3d.new x,y,0 #2
				vec_quadrants = screen_center_circle.vector_to(screen_control_pts) #3
				vec_centertomouse = screen_center_circle.vector_to screen_mouse #3
				vec_angles_screen = vec_centertomouse.angle_between(vec_quadrants) #4
				#######
				anchorangle = getAnchorAngle(view,x,y)
				vec_angles_screen = anchorangle.degrees if anchorangle!=nil
				#######
				angle = PI/2-vec_angles_screen  #угол от +PI/2 до -PI/2 если угол отвода равен -PI/2 значит он 180 градусов, при angle=0 отвод 90 градусов
				#puts "angle2=#{angle.radians.to_i}"
				@angle_grad = (vec_angles_screen*180/PI).to_i
				str_angle = @angle_grad.to_s
				Sketchup.vcb_value= str_angle + "°" #Печатаем найденный угол в зону контроля значения (в градусах)
				vector = [0,0,1]
				@elbowCurve_trans = Geom::Transformation.rotation point, vector, angle
                #point2 = ([radius,radius+2*dn,0]).transform(@elbowCurve_trans)
                # point2 = ([radius,radius+2*du,0]).transform(@elbowCurve_trans)
                point2 = ([0, 2*du, 0]).transform(@elbowCurve_trans)
				@elbow_curve_vec = ([point,point2]).collect{|pt|;pt.transform(transformation).transform(@transform_point).transform(@rot_trans)} #Вектор указываюший степень закругления
				########
				segm = @param[:Cегментов].to_i
                #radius=@param[:РадиусИзгиба].to_f*dn.mm
                # radius=@param[:КоэфРадиусаОтИзгиба].to_f*du.mm
                radius = @param[:РадиусИзгиба].mm
				delta_angle = 360/segm
				circle_dots = generate_arc(dn/2,0,360,delta_angle)
				vector=[0,-1,0]
				point= [radius,0,0]
				angle = PI/2-angle
					elbow_dots = []
				(360-(angle*180/PI).to_i).step(360,delta_angle){|myangle|  #Расположение опорных окружностей по отводу
					transformation = Geom::Transformation.rotation point, vector, myangle.degrees
					elbow_dots << circle_dots.collect {|pt|;pt.transform(transformation)}
				}
				elbow_dots << circle_dots.collect {|pt|;pt}
				@draw_elbow_pts = elbow_dots.collect{|dots|;dots.collect{|dot|;dot.transform(@transform_point).transform(@rot_trans)}}
				#----- Центральная точка осевой линии
				@pt_ccline = [0,0,0]
				transformation = Geom::Transformation.rotation point, vector, (360-(angle*180/PI/2)).degrees
				@pt_ccline = @pt_ccline.transform(transformation).transform(@transform_point).transform(@rot_trans)
			end
        end

        def create_elbow_param(ph,x,y,view)              #Создание параметров отвода относительно места присоединения
			component = ph.best_picked  #это компонент к которому прилипает отвод
			face_component = ph.picked_face #это активная поверхность (например конец трубопровода)
			connector_attribute = Sketchup::CoolPipe::cp_getattributes(face_component)
			attributes = Sketchup::CoolPipe::cp_getattributes(component)
			@param[:Тип]           = "Отвод"
			@param[:ЕдИзм]         = $coolpipe_langDriver["шт"]
			if attributes[:Dнар]!=nil
				@param[:Dнар]      = attributes[:Dнар]
                @param[:стенка]    = attributes[:стенка]
                @param[:Du]        = get_du(@param[:Dнар].to_f, @param[:стенка].to_f)
				@param[:Имя]       = $coolpipe_langDriver["Отвод"]+" Ø#{attributes[:Dнар]}х#{attributes[:стенка]} (R=#{$cp_elbowK}DN)"
			else
				@param[:Dнар]      = @alt_dn #Альтернативный диаметр для переходов и тройников
                @param[:стенка]    = @alt_st
                @param[:Du]        = get_du(@alt_dn.to_f, @alt_st.to_f)
                @param[:Имя]       = $coolpipe_langDriver["Отвод"]+" Ø#{@alt_dn}х#{@alt_st} (R=#{$cp_elbowK}DN)"
			end
			@param[:ГОСТ]          = "Документ"
			@param[:УголОтвода]    = 90
            @param[:КоэфРадиусаОтИзгиба]  = $cp_elbowK
            @param[:РадиусИзгиба]  = @param[:КоэфРадиусаОтИзгиба] * @param[:Du]
			@param[:Cегментов]     = $cp_segments
            @param[:typemodel]     = "cyl"
            #puts "@param Du = " + @param[:Du].to_s
        end

        def get_connectorspoints(component,trans)        #РЕКУРСИВНАЯ ФУНКЦИЯ Поиск точек коннекторов считанных с круговых поверхностей по vertex'ам
			connectors = []
			component_class = component.class.to_s
			case component_class
				when "Sketchup::Group"
					component.entities.each{|entity|;connectors = connectors + get_connectorspoints(entity,trans)}
				when "Sketchup::ComponentInstance"
					component.definition.entities.each{|entity|;connectors = connectors + get_connectorspoints(entity,trans)}
				else
					attribute = component.get_attribute("CoolPipeComponent","Тип")
					if attribute=="Коннектор"
						bb = Geom::BoundingBox.new
						vertices = component.vertices
						vertices.each{|vertex|;bb = bb.add(vertex);}
						connectors << bb.center.transform!(trans)
					end
			end
			connectors.compact
			connectors
		end
        def getfaceconnector(point,component,trans)      #РЕКУРСИВНАЯ ФУНКЦИЯ находит объект класса Face в компоненте, точка которой является серединой этого face
			component_class = component.class.to_s
			face = nil
			case component_class
				when "Sketchup::Group"
					component.entities.each{|entity|;face = getfaceconnector(point,component,trans)}
				when "Sketchup::ComponentInstance"
					component.definition.entities.each{|entity|;face = getfaceconnector(point,component,trans)}
				else
					attribute = component.get_attribute("CoolPipeComponent","Тип")
					if attribute=="Коннектор"
						bb = Geom::BoundingBox.new
						vertices = component.vertices
						vertices.each{|vertex|;bb = bb.add(vertex);}
						face=component if (point==bb.center.transform!(trans))
					end
			end
			face
		end
        def onKeyDown(key, repeat, flags, view)          #Обработка нажатий клави на клавиатуре при нажатии
			if( key == CONSTRAIN_MODIFIER_KEY && repeat == 1 )
				@shift_down_time = Time.now
				if( view.inference_locked? )
					view.lock_inference
				elsif( @state == STATE_SELECT_FIRST_POINT && @ip1.valid? )
					view.lock_inference @ip1
					generate_elbow_dots #Создание опорных точек для построения отвода
				elsif( @state == STATE_SET_ANGLE && @ip1.valid? )
					view.lock_inference @ip1, @ip2
				elsif( @state == STATE_SET_RADIUS_ANGLE && @ip1.valid? )
					view.lock_inference @ip2, @ip3
				end
			end
			super(key, repeat, flags, view)
		end
        def onLButtonDown(flags, x, y, view)             #Нажатие на левую клавишу мыши
			if  @state == STATE_SELECT_FIRST_POINT
				@ip1.pick view, x, y
				if @draw_elbow_pts.length>0 #если есть отображение сетки, можно переходить к следующему этапу
					if( @ip1.valid? )
						Sketchup::set_status_text($coolpipe_langDriver["Задать угол направления отвода"], SB_PROMPT)
						@xdown = x
						@ydown = y
					end
					if @drawconnector
						@ip1 = Sketchup::InputPoint.new(@connector_point)
						@state = STATE_SET_ANGLE
                    end
                end
			elsif @state == STATE_SET_ANGLE
				@ip2.pick view, x, y
				if( @ip2.valid? )and(@param[:angleDegrees]==nil)
					@state = STATE_SET_RADIUS_ANGLE
					Sketchup::set_status_text($coolpipe_langDriver["Задать угол геометрии отвода"], SB_PROMPT)
				else #Значит фиксированный угол отвода 90 градусов
					@angle_grad = 90
					@param[:view]=view
					cp_create_elbow_geometry   if $cp_vnGeom==true
					cp_create_cylindr_geometry if $cp_vnGeom==false
					Sketchup.active_model.select_tool nil
                end
			elsif @state == STATE_SET_RADIUS_ANGLE #После получения всех данных - рисуем отвод и завершаем класс
				@ip3.pick view, x, y
				if( @ip3.valid? )
					@param[:view]=view
					cp_create_elbow_geometry   if $cp_vnGeom==true
					cp_create_cylindr_geometry if $cp_vnGeom==false
					Sketchup.active_model.select_tool nil
				end
			end
			view.lock_inference
		end
		def onUserText(text, view)                       #Обработка пользовательского ввода значений углов
			begin
				value = text.to_i
			rescue
				UI.beep
				puts $coolpipe_langDriver["Не могу конвертировать в целочисленный градус"]+" "+text
				value = nil
				Sketchup::set_status_text "", SB_VCB_VALUE
			end
			return if (value==nil)
			generate_elbow_dots #Обновление сетки для полигонов
			case @state
				when STATE_SET_ANGLE
					@user_change_angle = true
					angle_rad = value.to_f*PI/180
					Sketchup.vcb_value= text + "°" #Печатаем найденный угол в зону контроля значения (в градусах)
					rot_trans = Geom::Transformation.rotation @connector_point, @connector_vector, angle_rad
					@elbow_direct_din = @elbow_direct.collect {|pt|;pt.transform(@transform_point).transform(rot_trans)}
					@draw_elbow_pts = @elbow_dots.collect{|dots|;dots.collect{|dot|;dot.transform(@transform_point).transform(rot_trans)}}
					@actual_point_rotate = @point_rotate.transform(@transform_point).transform(rot_trans)
					@rot_trans = rot_trans
					if( @ip2.valid? )and(@param[:angleDegrees]==nil)
						@state = STATE_SET_RADIUS_ANGLE
						Sketchup::set_status_text($coolpipe_langDriver["Задать угол геометрии отвода"], SB_PROMPT)
					else #Значит фиксированный угол отвода 90 градусов
						@angle_grad = 90
						Sketchup.active_model.select_tool nil
						@param[:view]=view
						cp_create_elbow_geometry   if @param[:typemodel]=="elbow"
						cp_create_cylindr_geometry if @param[:typemodel]=="cyl"
					end
				when STATE_SET_RADIUS_ANGLE
					value = 180    if (value>180)or(value<-180)
					value = -value if value<0
					angle_rad = value.to_f*PI/180
					@user_change_radius_angle = true

                    dn = @param[:Dнар].to_f
                    du = @param[:Du].to_f
                    radius = @param[:РадиусИзгиба].to_f

                    point = Geom::Point3d.new(radius.mm * $cp_elbowK,0,0)
					move = Geom::Transformation.new point
					transformation =Geom::Transformation.rotation(point,[1,0,0],90.degrees)
                    arc = generate_arc(3* @param[:Du],-90,90,5)
					movearc = arc.collect{|pt|;pt.transform(move)}
					@angle_panel_dots = movearc.collect{|pt|;pt.transform(transformation).transform(@transform_point).transform(@rot_trans)} #Полуокружность для рисования панели выбора градуса поворота отвода
					########
					angle = PI/2-angle_rad  #угол от +PI/2 до -PI/2 если угол отвода равен -PI/2 значит он 180 градусов, при angle=0 отвод 90 градусов
					@angle_grad = value
					str_angle = @angle_grad.to_s
					Sketchup.vcb_value= str_angle + "°" #Печатаем найденный угол в зону контроля значения (в градусах)
					vector = [0,0,1]
					@elbowCurve_trans = Geom::Transformation.rotation point, vector, angle
                    point2 = ([radius, radius + 2 * du ,0]).transform(@elbowCurve_trans)
					@elbow_curve_vec = ([point,point2]).collect{|pt|;pt.transform(transformation).transform(@transform_point).transform(@rot_trans)} #Вектор указываюший степень закругления
					########
					segm = @param[:Cегментов].to_i
					delta_angle = 360/segm
                    circle_dots = generate_arc(dn/2,0,360,delta_angle)
                    vector=[0,-1,0]
                    point= [radius.mm,0,0]
					angle = PI/2-angle
					elbow_dots = []
					(360-(angle*180/PI).to_i).step(360,delta_angle){|myangle|
						transformation = Geom::Transformation.rotation point, vector, myangle.degrees
						elbow_dots << circle_dots.collect {|pt|;pt.transform(transformation)}
					}
					elbow_dots << circle_dots.collect {|pt|;pt}
					@draw_elbow_pts = elbow_dots.collect{|dots|;dots.collect{|dot|;dot.transform(@transform_point).transform(@rot_trans)}}
					#----- Центральная точка осевой линии
					@pt_ccline = [0,0,0]
					transformation = Geom::Transformation.rotation point, vector, (360-(angle*180/PI/2)).degrees
					@pt_ccline = @pt_ccline.transform(transformation).transform(@transform_point).transform(@rot_trans)
					#------------------------------------
					Sketchup.active_model.select_tool nil
					@param[:view]=view
					cp_create_elbow_geometry   if $cp_vnGeom==true
					cp_create_cylindr_geometry if $cp_vnGeom==false
			end
		end
        def generate_elbow_dots                  #Создание опорных точек для построения отвода
            diam = @param[:Dнар].to_f            #Наружний диаметр отвода
            wall = @param[:стенка].to_f          #Толщина стенки отвода
            radius = @param[:РадиусИзгиба].to_f  #Радиус изгиба отвода

			segm = @param[:Cегментов].to_i       #Кол-во сегментов
			point= [radius.to_f.mm,0,0]          #Точка вокруг которой рисуется отвод
			vector=[0,-1,0]                      #Вектор вокруг которого рисуется отвод
			circle_dots = []
			delta_angle = 360/segm
			circle_dots = generate_arc(diam/2,0,360,delta_angle)
			@elbow_vector = Geom::Vector3d.new 1,0,0 #вектор направления отвода, т.е. куда он поворачивает
			@elbow_basevec= Geom::Vector3d.new 0,0,1 #вектор вокруг которого будет осуществляться вращение отвода
			@elbow_dots = []            #Массив массивов окружностей размещенных по радиусу закругления отвода от начала координат
			270.step(360,delta_angle){|angle|
				transformation = Geom::Transformation.rotation point, vector, angle.degrees
				@elbow_dots << circle_dots.collect {|pt|;pt.transform(transformation)}
			}
			@elbow_direct = [[0,0,0],point] #Линия направления отвода (указывает куда поворачивает сам отвод)
            angle_panel_dots = generate_arc(diam+radius,0,180,delta_angle) #точки панели для задания угла отвода от 0 до 180 градусов
			transformation =Geom::Transformation.rotation(point,vector,90.degrees)
			@angle_panel_dots = angle_panel_dots.collect {|pt|pt.transform(transformation)}
			@point_rotate = point
			@elbow_dots.compact
		end
        def draw(view)                                   #Визуализация действий при рисовании трубы (вывод сетки, маркеров, коннекторов и т.д.)
			i = 0
			case @state
				when STATE_SELECT_FIRST_POINT #Место расположение отвода
					if @drawconnector
						generate_elbow_dots #отрисовка отвода по заданным характеристикам
						draw_elbow_dots(view)
						view.line_stipple = ""
						view.draw_points  @connector_point, 10, 1, "red" if (@connector_point!=nil)&&(@connector_vector!=nil)
					end
				when STATE_SET_ANGLE
					view.drawing_color = "Black"
					view.line_stipple = ""
					if (@sel_angle_panel!=nil)and(@sel_angle_panel!=[])
						view=view.draw GL_LINE_LOOP, @sel_angle_panel #отрисовка окружности
						draw_elbow_dots(view) #отрисовка отвода по заданным характеристикам
						k = 95
						@sel_angle_panel.each{|pt1|  #Отрисовка засечек
							view.line_stipple = ""
							i+=1
							k = k-5
							k = 355 if k<0
							if [4,7,13,16,22,25,31,34,40,43,49,52,58,61,67,70].include?(i)
								pt2 = Geom::Point3d.linear_combination 0.2,@connector_point,0.8,pt1
								vec = pt1.vector_to pt2
								axes = vec.axes
								addAnchorAngle(view,pt2,@connector_vector,@mx,@my,k)#axes.x,@mx,@my,k)
							elsif [1,10,19,28,37,46,55,64].include?(i)
								pt2 = Geom::Point3d.linear_combination 0.3,@connector_point,0.7,pt1
								vec = pt1.vector_to pt2
								axes = vec.axes
								addAnchorAngle(view,pt2,@connector_vector,@mx,@my,k)#axes.x,@mx,@my,k)
							else
								pt2 = Geom::Point3d.linear_combination 0.1,@connector_point,0.9,pt1
							end
							view.drawing_color = "black"
							view = view.draw_line pt1,pt2
						}
						view.drawing_color = "Green"
						view=view.draw GL_LINE_LOOP,@elbow_direct_din
					end
					view.draw_points  @ip4.position, 3, 1, "blue" if ( @ip4.valid? )  #Отображение точки привязки
				when STATE_SET_RADIUS_ANGLE
					view.drawing_color = "Black"
					view.line_stipple = ""
					if (@angle_panel_dots!=nil) and (@angle_panel_dots!=[])
						view=view.draw GL_LINE_LOOP, @angle_panel_dots #отрисовка окружности
						draw_elbow_dots(view)  #отрисовка отвода по заданным характеристикам
						@angle_panel_dots.each{|pt1|  #Отрисовка засечек
							view.line_stipple = ""
							i+=1
							if [4,7,13,16,22,25,31,34].include?(i)
								pt2 = Geom::Point3d.linear_combination 0.2,@actual_point_rotate,0.8,pt1
								vec = pt1.vector_to pt2
								axes = vec.axes
								addAnchorAngle(view,pt2,@connector_vector.axes.x,@mx,@my,5*(i-1))
								addAnchorAngle(view,pt2,@connector_vector.axes.y,@mx,@my,5*(i-1))
							elsif [1,10,19,28].include?(i)
								pt2 = Geom::Point3d.linear_combination 0.3,@actual_point_rotate,0.7,pt1
								vec = pt1.vector_to pt2
								axes = vec.axes
								addAnchorAngle(view,pt2,@connector_vector.axes.x,@mx,@my,5*(i-1)) if i!=1
								addAnchorAngle(view,pt2,@connector_vector.axes.y,@mx,@my,5*(i-1)) if i!=1
							else
								pt2 = Geom::Point3d.linear_combination 0.1,@actual_point_rotate,0.9,pt1
							end
							view.drawing_color = "black"
							view = view.draw_line pt1,pt2 if (i!=1)&&(i!=37)
						}
						view=view.draw_points @actual_point_rotate, 10, 3, "Blue"
						if @elbow_curve_vec!=nil
							view=view.draw GL_LINE_LOOP,@elbow_curve_vec if @elbow_curve_vec.length==2
						end
					end
					view.draw_points  @ip3.position, 3, 1, "brown" if ( @ip3.valid? )  #Отображение точки привязки
			end
		end
        def draw_elbow_dots(view)                        #Отрисовка сетки будущего отвода
			draw_array_circlepts(@draw_elbow_pts,view)
		end
        def cp_createelbowattributes(param)              #создает список атрибутов для Отвода
			attributes={}
			if param!=nil
			apr = @actual_point_rotate
			vershina = @pt_ccline    #центр осевой линии (для себя назвал - вершина отвода)
			attributes={:Тип            => "Отвод",                         #Тип компонента: отвод
						:Имя            => "#{param[:Имя]} #{@angle_grad}°",#Наименование трубы для спецификации
						:ЕдИзм          => $coolpipe_langDriver["шт"],      #Единица измерения для спецификации
						:Dнар           => param[:Dнар],
						:стенка         => param[:стенка],
						:РадиусИзгиба   => param[:РадиусИзгиба].to_f, #Радиус закругления отвода
						:ГОСТ           => "Документ",                      #Нормативный документ (из базы)
						:Материал       => param[:Материал],                #Материал трубопровода (собственный цвет из настроек слоев)-если нет то 0
						:УголОтвода     => @angle_grad,                     #Угол поворота отвода
						:PointRotate    => "#{apr.x.to_mm}|#{apr.y.to_mm}|#{apr.z.to_mm}", #Точка вокруг которой строится отвод
						:Vershina		=> "#{vershina.x.to_mm}|#{vershina.y.to_mm}|#{vershina.z.to_mm}", #Вершина отвода
						:typemodel      => "cyl",                           #Тип отрисованного объекта (cyl = цилиндрический, elbow = с внутренней геометрией)
						:Стандартный_элемент =>"true"				             #элемент является стандартным #-добавка версии 1.4.1(2018)
						}
			attributes[:Dнар]  = if (@alt_dn==nil) then param[:Dнар]   else @alt_dn end
			attributes[:стенка]= if (@alt_st==nil) then param[:стенка] else @alt_st end
			attributes[:Имя]   = $coolpipe_langDriver["Отвод"]+" Ø#{attributes[:Dнар]}х#{attributes[:стенка]} (R=#{$cp_elbowK}DN) #{@angle_grad}°"
			attributes[:масса] = cp_elbow_massa(attributes) #Масса единицы для спецификации
			end
			attributes
		end #cp_createelbowattributes(param)
        def cp_elbow_massa(attributes)                       #Вычисление  массы отвода с заданными параметрами из массы 90 градусного отвода
			dnstring = attributes[:Dнар]                      #Диаметр в мм строковой
			ststring = attributes[:стенка]                    #Толщина стенки в мм строковая
			alpha = @angle_grad.to_f                          #Угол отвода в градусах
			dn = dnstring.to_f/10                             #Диаметр в см
			st = ststring.to_f/10                             #Толщина стенки в см
			rd = attributes[:РадиусИзгиба].to_f / 10          #Радиус закругления отвода в см
			v1 = (PI*PI*rd*dn*dn/2)*(alpha/360)               #Объем внешнего отвода см3
			v2 = (PI*PI*rd*(dn-2*st)*(dn-2*st)/2)*(alpha/360) #Объем внутреннего отвода см3
			vo = v1 - v2                                      #Объем отвода за вычетом внутренней геометрии
			massa = ($cp_elbowPlotnost * vo).to_i.to_f/1000   #Масса отвода кг, где $cp_elbowPlotnost=7,85 г/см3 - плотность
			puts $coolpipe_langDriver["Расчетная масса отвода"]+" Ø#{dnstring}x#{ststring} #{@angle_grad}° = #{massa} кг(kg)"
			massa
		end #cp_elbow_massa
        def cp_create_elbow_geometry                     #ОТРИСОВЩИК - Создет геометрию отвода по переданным параметрам
			if @draw_elbow_pts.length>0
				view = @param[:view]
				prevlayer1 = setactivLayer(@layer) if @layer!=nil # Устанавливаем активный слой если задан в параметрах
				model = view.model
				model.start_operation "Создание объекта CoolPipe::CircleElbow"
				entities = model.active_entities
				groupglob=entities.add_group
				entities = groupglob.entities
				group=entities.add_group
				entities = group.entities
				component=groupglob.to_component
				attributes = cp_createelbowattributes(@param)
				name = attributes[:Имя]
				component.name = "Elbow: #{name}"
				component.definition.name="Elbow: #{name}"
				mesh = Geom::PolygonMesh.new
				mesh2= Geom::PolygonMesh.new
				pre_pts = nil
				pre_scalepts = nil
				pre_center = nil
				base_circles = []
				future_arc_pts = []
				connector_pts = []
				scale = (@param[:Dнар].to_f-2*@param[:стенка].to_f)/@param[:Dнар].to_f #Коэффициент масштаба для внутренней поверхности трубы относительно наружного диаметра
				scale = (@alt_dn.to_f-2*@alt_st.to_f)/@alt_dn.to_f if scale==1
				for j in 0..(@draw_elbow_pts.length-1)
					pts = @draw_elbow_pts[j]
					if pre_pts!=nil
						if pts!=pre_pts
							for i in 0..(pts.length-2)
								point1 = pts[i]
								point2 = pts[i+1]
								point3 = pre_pts[i+1]
								point4 = pre_pts[i]
								mesh.add_polygon point1, point2, point3, point4
							end
						end
						pre_pts = pts
					else
						pre_pts = pts
					end
					#Далее ищем точки для осевой линии
					bbox = Geom::BoundingBox.new
					bbox = bbox.add pts
					center = bbox.center
					future_arc_pts << center #Собираем опорные точки будущей осевой линии отвода
					if ((j==0) or (j==@draw_elbow_pts.length-1))and (center!=nil)
						connector_pts << connector = entities.add_cpoint(center)
						connectorvec = (center.vector_to(pts[0]) * center.vector_to(pts[(pts.length/4).to_i])).reverse!
						set_connector_point(connector,connectorvec)          if j==0
						set_connector_point(connector,connectorvec.reverse!) if j==@draw_elbow_pts.length-1
					end
					#Далее получаем полигоны внутренней поверхности отвода
					scale_transform = Geom::Transformation.scaling center, scale #смысл: изменение расстояния до точки путем масштабирования (относительно центра pts окружности)
					scale_pts = pts.collect{|pt|;pt.transform scale_transform} #получаем массив точек внутренней окружности
					base_circles << scale_pts if (j==0)or(j==@draw_elbow_pts.length-1)
					if pre_scalepts!=nil
						if scale_pts!=pre_scalepts
							for i in 0..(scale_pts.length-2)
								point1 = scale_pts[i]
								point2 = scale_pts[i+1]
								point3 = pre_scalepts[i+1]
								point4 = pre_scalepts[i]
								mesh2.add_polygon point1, point2, point3, point4 #строим полигоны внутреней поверхности отвода
							end
						end
						pre_scalepts = scale_pts
					else
						pre_scalepts = scale_pts
					end
				end
				puts "#{$coolpipe_langDriver["Количество полигонов составляет"]} #{mesh.count_polygons+mesh2.count_polygons}"
				entities.add_faces_from_mesh mesh #Наружняя поверхность отвода
				entities.each{|face|;face.reverse! if face.class==Sketchup::Face}
				entities.add_faces_from_mesh mesh2 #Внутреняя поверхность отвода
				face1 = entities.add_face @draw_elbow_pts[0]
				face2 = entities.add_face @draw_elbow_pts[@draw_elbow_pts.length-1]
				face3 = (entities.add_face base_circles[0]) if base_circles[0]!=nil
				face4 = (entities.add_face base_circles[1]) if base_circles[1]!=nil
				face3.hidden = true if face3!=nil
				face4.hidden = true if face4!=nil
				# Рисуем осевую линию (количество сегментов 1шт на 2 градуса)
				mpt = @pt_ccline
				vec_cc1 = @actual_point_rotate.vector_to connector_pts[0].position
				vec_cc2 = @actual_point_rotate.vector_to connector_pts[1].position
				vec_cc2 = @actual_point_rotate.vector_to mpt if (vec_cc1.parallel? vec_cc2)
				cross_cc= vec_cc1.cross vec_cc2
				if (@alt_dn==nil) or (@alt_dn==@param[:Dнар])
					diam = @param[:Dнар].to_f       #Наружний диаметр отвода
				else
					diam  = @alt_dn.to_f            #Наружний диаметр отвода
				end
                centerline_arc = entities.add_arc @actual_point_rotate,vec_cc1,cross_cc,(@param[:КоэфРадиусаОтИзгиба].to_f.mm*@param[:Du].to_f),0.degrees,@angle_grad.degrees,@angle_grad/2
				######
				######
				# Скрытая геометрия для дальнейшего поиска коннекторов
				point3 = entities.add_cpoint @actual_point_rotate  #Точка вокруг которой строится отвод
				point4 = entities.add_cpoint mpt #средняя точка осевой линии
				point3.hidden = true
				point4.hidden = true
				point3.set_attribute "CoolPipeComponent","ActualPointRotate",0
				point4.set_attribute "CoolPipeComponent","CenterCenterLine",1
				######
				cp_setattributes(attributes,component)
				setactivLayer(prevlayer1) if prevlayer1!=nil #Восстанавливаем исходный слой
				component.material = @material if @material!=nil
				model.commit_operation
				puts "#{$coolpipe_langDriver["Начерчен: "]} #{name}"
			end
			component
		end #cp_create_elbow_geometry(param)
        def cp_create_cylindr_geometry                   #ОТРИСОВЩИК - Создет геометрию отвода в виде закругленного цилиндра по переданным параметрам
			if @draw_elbow_pts.length>0
				view = @param[:view]
				prevlayer1 = setactivLayer(@layer) if @layer!=nil # Устанавливаем активный слой если задан в параметрах
				model = view.model
				model.start_operation "Создание объекта CoolPipe::CircleElbow"
				entities = model.active_entities
				groupglob=entities.add_group
				entities = groupglob.entities
				group=entities.add_group
				entities = group.entities
				component=groupglob.to_component
				attributes = cp_createelbowattributes(@param)
				name = attributes[:Имя]
				component.name = "Elbow: #{name}"
				component.definition.name="Elbow: #{name}"
				mesh = Geom::PolygonMesh.new
				pre_pts = nil
				pre_center = nil
				#future_arc_pts = []
				connector_pts = []
				@draw_elbow_pts.each {|pts| #pts - точки опорных окружностей сегментов
					if pre_pts!=nil
						if pts!=pre_pts
							for i in 0..(pts.length-2)
								point1 = pts[i]
								point2 = pts[i+1]
								point3 = pre_pts[i+1]
								point4 = pre_pts[i]
								mesh.add_polygon point1, point2, point3, point4
							end
						end
						pre_pts = pts
					else
						pre_pts = pts
					end
				}
				puts "#{$coolpipe_langDriver["Количество полигонов составляет"]} #{mesh.count_polygons} #{$coolpipe_langDriver["шт"]}"
				entities.add_faces_from_mesh mesh
				entities.each{|face|;face.reverse! if face.class==Sketchup::Face}
				#Рисуем заглушки для концов отвода
				face1 = entities.add_face @draw_elbow_pts[0]
				face2 = entities.add_face @draw_elbow_pts[@draw_elbow_pts.length-1]
				point1=entities.add_cpoint(Geom::BoundingBox.new.add(@draw_elbow_pts[0]).center)
				point2=entities.add_cpoint(Geom::BoundingBox.new.add(@draw_elbow_pts[@draw_elbow_pts.length-1]).center)
				# Рисуем осевую линию (количество сегментов 1шт на 2 градуса)
				mpt = @pt_ccline
				vec_cc1 = @actual_point_rotate.vector_to point1.position
				vec_cc2 = @actual_point_rotate.vector_to point2.position
				vec_cc2 = @actual_point_rotate.vector_to mpt if (vec_cc1.parallel? vec_cc2)
				cross_cc= vec_cc1.cross vec_cc2
				if (@alt_dn==nil) or (@alt_dn==@param[:Dнар])
					diam = @param[:Dнар].to_f       #Наружний диаметр отвода
				else
					diam  = @alt_dn.to_f            #Наружний диаметр отвода
				end
                centerline_arc = entities.add_arc @actual_point_rotate,vec_cc1,cross_cc,(@param[:КоэфРадиусаОтИзгиба].to_f.mm * @param[:Du]),0.degrees,@angle_grad.degrees,@angle_grad/2
				######
				# Скрытая геометрия для дальнейшего поиска коннекторов
				point3 = entities.add_cpoint @actual_point_rotate  #Точка вокруг которой строится отвод
				point4 = entities.add_cpoint mpt #средняя точка осевой линии
				point3.hidden = true
				point4.hidden = true
				point3.set_attribute "CoolPipeComponent","ActualPointRotate",0
				point4.set_attribute "CoolPipeComponent","CenterCenterLine",1
				######
				vec1 = face1.normal
				vec2 = face2.normal
				set_connector_point(point1,vec1)
				set_connector_point(point2,vec2)
				behavior = component.definition.behavior #Для ограничения вариантов масштабирования объекта
				mask = (1<<0)+(1<<1)+(1<<2)+(1<<3)+(1<<4)+(1<<5)+(1<<6) #запрет масштабирования
				behavior.no_scale_mask = mask #Применяем маску
				cp_setattributes(attributes,component)
				setactivLayer(prevlayer1) if prevlayer1!=nil #Восстанавливаем исходный слой
				component.material = @material if @material!=nil
				model.commit_operation
				puts "#{$coolpipe_langDriver["Начерчен: "]} #{name}"
			end
			component
        end #cp_create_cylindr_geometry

        def get_du(dn, st)                              #Возвращает Du по Dn (Наружный диаметр) и St (толщина стенки)
            du_all=[10, 15, 20, 25, 32, 40, 50, 65, 80, 90, 100, 125, 150, 200, 225, 250, 300, 350, 400, 450, 500, 600, 700, 800, 900, 1000, 1200, 1400]
            dv = dn-2*st
            array = du_all.map{ |elem| (elem-dv).abs}
            du = du_all[array.each_with_index.sort.map(&:last).first(1)[0]]
            du
            end

	end #class ToolDrawElbow < ToolDrawElement
	######
	class ToolDrawReducer < ToolDrawElement  #Инструмент отрисовки переходника
		def initialize(param,redraw = false)             #Инициализация объекта
			super(param)
			@reducer_dots = []
			generate_reducer_dots #Создание опорных точек для построения перехода
			@user_change_angle = false
			@user_change_radius_angle = false
			Sketchup::set_status_text($coolpipe_langDriver["Указать место расположения перехода"], SB_PROMPT) if redraw==false
			if redraw!=false #Флаг, указывающий что требуется перерисовка перехода (значения либо false по умолчанию, либо предыдущий компонент)
				transform = redraw.transformation #Копируем трансформации из существующего объекта
				@draw_reducer_pts = @reducer_dots#.collect{|dots|;dots.collect{|dot|;dot.transform(transform)}} #Для рисования сетки перехода
			end
		end #def initialize(ini)
		def reset(view)                                  #Сброс настроек
			@state = STATE_SELECT_FIRST_POINT
			Sketchup::set_status_text("Указать место расположения перехода", SB_PROMPT)
			@ip1.clear if @ip1!=nil
			@ip2.clear if @ip2!=nil
			@ip. clear if @ip !=nil
			if(view)
				view.invalidate if @drawn
			end
			@drawn = false
			@connector_vector=nil
			@draw_reducer_pts = []
		end
		def getExtents                                   #Указывает Sketchup границы рисования для View
			bounds = Sketchup.active_model.bounds
			@draw_reducer_pts.each{|dots|;dots.each{|pt|;bounds.add(pt)}} if @draw_reducer_pts!=nil
			@angle_panel_dots.each{|pt|;bounds.add(pt)} if @angle_panel_dots!=nil
			return bounds
		end
		def enableVCB?                                   #Разрешение/Запрещение пользовательского ввода
			return false if @state == STATE_SELECT_FIRST_POINT   #запрещаем пользовательский ввод
			return true  if @state == STATE_SET_ANGLE            #разрешаем пользовательский ввод
		end
		def onMouseMove(flags, x, y, view)               #Событие возникает при перемещении указателя мыши
			@param[:view]=view
			view.model.selection.clear #Если что-то выделено - снять выделение
			case @state
				when STATE_SELECT_FIRST_POINT
					onMouseMove_StateSelectFirstPoint(flags, x, y, view)
				when STATE_SET_ANGLE
					onMouseMove_StateSetAngle(flags, x, y, view)
			end
			view.invalidate
		end
		def onMouseMove_StateSelectFirstPoint(flags, x, y, view)   #Обработчик движения мыши при выборе точки расположения перехода (перемещение сетки)
			@ip.pick view, x, y
			ph = view.pick_helper
			ph.do_pick x,y
			component = ph.best_picked
			if Sketchup::CoolPipe::cp_iscpcomponent?(component)  #Указатель мыши над компонентом CoolPipeComponent
				@drawconnector=true
				trans = component.transformation
				where_connector(component,x,y,view,trans) #Определяет положение ближайшего коннектора и направление вектора (если такие есть)
				if (@connector_vector!=nil)and(@connector_point!=nil)
					@transform_point = Geom::Transformation.new @connector_point,@connector_vector.normalize
					@reducer_vector = (Geom::Vector3d.new 1,0,0).transform(@transform_point)
					@reducer_basevec= (Geom::Vector3d.new 0,1,0).transform(@transform_point)
					@first_rotate = Geom::Transformation.rotation @connector_point, @reducer_basevec, -90.degrees
					@draw_reducer_pts = @reducer_dots.collect{|dots|;dots.collect{|dot|;dot.transform(@transform_point).transform(@first_rotate)}} #Для рисования сетки перехода
					@connector_point = (Geom::Point3d.new).transform(@transform_point)
					@marker = 1
				end
			else
				@drawconnector=false
				@transform_point = Geom::Transformation.new @ip.position
				@connector_point = (Geom::Point3d.new).transform(@transform_point)
				@reducer_vector = (Geom::Vector3d.new 1,0,0).transform(@transform_point)
				@reducer_basevec= (Geom::Vector3d.new 0,1,0).transform(@transform_point)
				@draw_reducer_pts = @reducer_dots.collect{|dots|;dots.collect{|dot|;dot.transform(@transform_point)}} #Для рисования сетки перехода
				@marker = 2
			end
		end
		def onMouseMove_StateSetAngle(flags, x, y, view) #Обработчик движения указателя мыши при выборе угла вращения вокруг точки вставки
			@ip2.pick view, x, y
			view.tooltip = @ip2.tooltip if( @ip2.valid? ) #отслеживание привязок по сторонней геометрии
			trans_rotate = Geom::Transformation.rotation([0,0,0], [0,0,1], 90.degrees) if @marker == 1
			trans_rotate = Geom::Transformation.rotation([0,0,0], [0,1,0], 90.degrees) if @marker == 2
			@sel_angle_panel = generate_arc(@param[:D1]*25.4,0,360,5).collect{|pt|;pt.transform(trans_rotate).transform(@transform_point)} #Окружность для рисования панели выбора градуса
			@reducer_direct_din = @reducer_direct.collect {|pt|;pt.transform(trans_rotate).transform(@transform_point)}
			@mouse_point = Geom::Point3d.new(x,y,0) #Мышь на экране
			@connectoronscreen = view.screen_coords @connector_point #Коннектор в координатах экрана
			vec_connect2mouse = @connectoronscreen.vector_to @mouse_point #Вектор от коннектора к мыши
			@point_anglevec = @connectoronscreen.offset vec_connect2mouse,150 if vec_connect2mouse.length>0 #Смещение коннектора по вектору для получения второй точки направляющей вращения
		end
		def onKeyDown(key, repeat, flags, view)          #Обработка нажатий клави на клавиатуре при нажатии
			if( key == CONSTRAIN_MODIFIER_KEY && repeat == 1 )
				@shift_down_time = Time.now
				if( view.inference_locked? )
					view.lock_inference
				elsif( @state == STATE_SELECT_FIRST_POINT && @ip1.valid? )
					view.lock_inference @ip1
				elsif( @state == STATE_SET_ANGLE && @ip1.valid? )
					view.lock_inference @ip1, @ip2
				end
			end
			if key.to_s=="27" #ESC
				Sketchup.active_model.select_tool(nil)
			end
		end
		def onLButtonDown(flags, x, y, view)             #Нажатие на левую клавишу мыши
			need_create_reducer = false
			@param[:view]=view
			if  @state == STATE_SELECT_FIRST_POINT #Завершение выбора местоположения перехода
				@ip1.pick view, x, y
				if( @ip1.valid? )
					case @param[:typeconstruction]
						when "concentric" #Если концентрический переход - то рисуем его в выбранном местоположении
							Sketchup.active_model.select_tool nil
							need_create_reducer = true
						when "eccentric" #Если эксцентрический переход - то требуется указать поворт перехода
							@state = STATE_SET_ANGLE
							Sketchup::set_status_text("Задать угол поворота эксцентрического перехода", SB_PROMPT)
							@xdown = x
							@ydown = y
					end
				end
				if @drawconnector
					@ip1 = Sketchup::InputPoint.new(@connector_point)
				end
			elsif @state == STATE_SET_ANGLE #После получения всех данных - рисуем переход и завершаем класс
				@ip2.pick view, x, y
				if( @ip2.valid? )
					Sketchup.active_model.select_tool nil
					need_create_reducer = true
				end
			end
			if need_create_reducer #выполнены все условия для начала рисования перехода
				cp_create_reducer_geometry if $cp_vnGeom==true
				cp_create_cylindr_geometry if $cp_vnGeom==false
			end
			view.lock_inference
		end
		def onUserText(text, view)                       #Обработка пользовательского ввода значений углов
			begin
				value = text.to_i
			rescue
				UI.beep
				puts "Не могу конвертировать в целочисленный градус "+text
				value = nil
				Sketchup::set_status_text "", SB_VCB_VALUE
			end
			return if (value==nil)
			case @state
				when STATE_SET_ANGLE
					@user_change_angle = true
					angle_rad = value.to_f*PI/180
					Sketchup.vcb_value= text + "°" #Печатаем найденный угол в зону контроля значения (в градусах)
					rot_trans = Geom::Transformation.rotation @connector_point, @elbow_basevec, angle_rad
					@elbow_direct_din = @elbow_direct.collect {|pt|;pt.transform(@transform_point).transform(rot_trans)}
					@draw_elbow_pts = @elbow_dots.collect{|dots|;dots.collect{|dot|;dot.transform(@transform_point).transform(rot_trans)}}
					@actual_point_rotate = @point_rotate.transform(@transform_point).transform(rot_trans)
					@rot_trans = rot_trans
					if( @ip2.valid? )and(@param[:angleDegrees]==nil)
						@state = STATE_SET_RADIUS_ANGLE
						Sketchup::set_status_text("Задать угол геометрии отвода", SB_PROMPT)
					else #Значит фиксированный угол отвода 90 градусов
						@angle_grad = 90
						Sketchup.active_model.select_tool nil
						@param[:view]=view
						cp_create_reducer_geometry  if $cp_vnGeom==true
						cp_create_cylindr_geometry  if $cp_vnGeom==false
					end
			end
		end
		def draw(view)                                   #Визуализация действий при рисовании элемента (вывод сетки, маркеров, коннекторов и т.д.)
			i = 0
			case @state
				when STATE_SELECT_FIRST_POINT #Место расположение отвода
					draw_reducer_dots(view)
					if @drawconnector
						view.line_stipple = ""
						view.draw_points  @connector_point, 10, 1, "red" if (@connector_point!=nil)&&(@connector_vector!=nil)
					end
				when STATE_SET_ANGLE
					view.drawing_color = "Black"
					view.line_stipple = ""
					if (@sel_angle_panel!=nil)and(@sel_angle_panel!=[])
						view=view.draw GL_LINE_LOOP, @sel_angle_panel #отрисовка окружности
						draw_reducer_dots(view)
						@sel_angle_panel.each{|pt1|  #Отрисовка засечек
							view.line_stipple = ""
							i+=1
							if [4,7,13,16,22,25,31,34,40,43,49,52,58,61,67,70].include?(i)
								pt2 = Geom::Point3d.linear_combination 0.2,@connector_point,0.8,pt1
							elsif [1,10,19,28,37,46,55,64].include?(i)
								pt2 = Geom::Point3d.linear_combination 0.3,@connector_point,0.7,pt1
							else
								pt2 = Geom::Point3d.linear_combination 0.1,@connector_point,0.9,pt1
							end
							view = view.draw_line pt1,pt2
						}
						view.drawing_color = "Green"
						view=view.draw GL_LINE_LOOP,@reducer_direct_din
					end
					view.draw_points  @ip2.position, 3, 1, "blue" if ( @ip2.valid? )  #Отображение точки привязки
			end
		end
		def draw_reducer_dots(view)                      #Отрисовка сетки будущего перехода
			view.line_stipple = ""
			if @draw_reducer_pts.length>0
				case @param[:typeconstruction]
					when "concentric"
						view.line_stipple = "."
						if @param[:typeconnect]=="smalltobig" #Если отображение не стандартное - поворачиваем переход на 180 градусов
							reducer_circles_pts = []
							for i in 0..(@draw_reducer_pts[0].length-1) #В цикле массив дуг преобразовывается в массив окружностей для определения точек коннекторов
								vncircle = []
								for j in 0..(@draw_reducer_pts.length-1)
									vncircle << @draw_reducer_pts[j][i] if @draw_reducer_pts[j][i]!=nil
								end
								reducer_circles_pts << vncircle if vncircle!=[]
							end
							pt1 = Geom::BoundingBox.new.add(reducer_circles_pts[0]).center
							pt2 = Geom::BoundingBox.new.add(reducer_circles_pts[reducer_circles_pts.length-1]).center
							vec1=pt1.vector_to pt2
							vec2=vec1.axes.x
							pt3 = Geom::Point3d.linear_combination 0.5, pt1, 0.5, pt2
							trans = Geom::Transformation.rotation pt3, vec2, 180.degrees
							@draw_reducer_pts = @draw_reducer_pts.collect{|dots|;dots.collect{|dot|;dot.transform(trans)}} #Поворот перехода на 180 градусов если требуется отрисовка от маленького диаметра к большому
						end
						@draw_reducer_pts.each{|curve|;view=view.draw GL_LINE_STRIP,curve} #отрисовка кривых по окружности
						view.line_stipple = ""
						for i in 0..(@draw_reducer_pts.length-1)
							for j in 0..@draw_reducer_pts[i].length
								point1 = @draw_reducer_pts[i][j]
								if @draw_reducer_pts[i+1]!=nil
									point2 = @draw_reducer_pts[i+1][j]
									view=view.draw GL_LINES,point1,point2 if (point1!=nil)and(point2!=nil)
								end
							end
						end
					when "eccentric"
						view.line_stipple = ""
						@draw_reducer_pts.each{|circle|;view=view.draw GL_LINE_STRIP,circle}
						view.line_stipple = "."
						for i in 0..(@draw_reducer_pts.length-1)
							for j in 0..@draw_reducer_pts[i].length
								point1 = @draw_reducer_pts[i][j]
								if @draw_reducer_pts[i+1]!=nil
									point2 = @draw_reducer_pts[i+1][j]
									view=view.draw GL_LINES,point1,point2 if (point1!=nil)and(point2!=nil)
								end
							end
						end
				end
			end
		end
		def generate_reducer_dots                        #Вычисление опорных точек сетки перехода в центре координат
			curve = get_curve_points(@param[:D1].to_f.mm/2,@param[:D2].to_f.mm/2,@param[:D1].to_f.mm*0.3,@param[:D2].to_f.mm*0.3,@param[:Длина].to_f.mm)
			@reducer_dots = []
			@reducer_dots << curve
			for i in 1..@param[:Сегментов] #В данном цикле будем поочередно вращать кривую вокруг оси Х, записывая каждое положение в массив
				rot_trans = Geom::Transformation.rotation [0,0,0],[1,0,0],(i*(360/@param[:Сегментов])).degrees
				@reducer_dots << curve.collect{|dot|;dot.transform(rot_trans)}
			end
		end
		def get_curve_points(r1,r2,rs1,rs2,l)            #Поиск опорных точек кривой объекта вращения
			#Входные параметры:
			#r1 - радиус начала перехода (больший радиус)
			#r2 - радиус конца перехода
			#rs1- радиус первого сопряжения
			#rs2- радиус второго сопряжения
			#l  - длина перехода
			curve = []  #Инициация массива точек дуги сопряжения
			if r2>r1    #Если перепутан порядок исходных данных r1 должен быть больше r2
				r = r1
				r1 = r2
				r2 = r
			end
			if rs2>rs1  #Если перепутан порядок исходных данных rs1 должен быть больше rs2
				rs = rs1
				rs1 = rs2
				rs2 = rs
			end
			h = (r1-r2)/2  #Высота занимаемая одной из дуг сопряжения
			y_step = h/(@param[:Сегментов]/4)  #Шаг (сегментация) дуги по оси Y
			points1 = [];points2 = []
			r1.step(r1-h,-y_step) do |y|;points1 << get_point_on_circleY(r1,y,1);end #Получение точек первой дуги относительно начала координат
			r2.step(r2-h,-y_step) do |y|;points2 << get_point_on_circleY(r2,y,1);end #Получение точек второй дуги относительно начала координат
			#puts "points1[points1.length-1].x=#{points1[points1.length-1].x}"
			#puts "points2[points2.length-1].x=#{points2[points2.length-1].x}"
			transformation1 = Geom::Transformation.rotation points2[0],[0,0,1],180.degrees #Поворот второй дуги на 180 градусов
			moveLength = points1[points1.length-1].x+points2[points2.length-1].x
			points2 = points2.reverse
			points2 = points2.collect{|dot|;dot.transform(transformation1).offset([1,0,0],moveLength)}
			curve = points1+points2
			all_x = []
			curve.each{|point|;all_x << point.x}
			max_x = all_x.max
			delta_length = (@param[:Длина].to_f.mm-max_x)/2 #Разница между длиной отвода и длиной кривой пополам (для смещения всей кривой по оси Х)
			curve = curve.collect{|dot|;dot.offset([1,0,0],delta_length)} #Смещение кривой по оси Х
			first_point  = Geom::Point3d.new(0,r1,0) #Первая точка кривой сопряжения
			finish_point = Geom::Point3d.new(@param[:Длина].to_f.mm,r2,0) #Последняя точка кривой сопряжения
			delta_Y = curve[0].y - first_point.y
			curve = curve.collect{|dot|;dot.offset([0,-1,0],delta_Y)} #Смещение кривой по оси Y
			reduce_curve = []
			reduce_curve << first_point
			curve.each{|point|;reduce_curve<<point}
			reduce_curve << finish_point
			curve = reduce_curve
			curve  #Возвращает массив точек сопряжения перехода
		end
		def get_point_on_circleX(r,x,n) #Возвращает точку на окружности лежащей в центре координат с радиусом R и по координате X, с указанием номера четверти окружности n
			#n - номер четверти против часовой стрелки начиная с правого верхнего угла
			y = Math.sqrt(r*r-x*x) if (n==1) or (n==2)
			y =-Math.sqrt(r*r-x*x) if (n==3) or (n==4)
			point = Geom::Point3d.new(x,y,0)
			point
		end
		def get_point_on_circleY(r,y,n) #Возвращает точку на окружности лежащей в центре координат с радиусом R и по координате Y, с указанием номера четверти окружности n
			#n - номер четверти против часовой стрелки начиная с правого верхнего угла
			x = Math.sqrt(r*r-y*y) if (n==1) or (n==4)
			x =-Math.sqrt(r*r-y*y) if (n==2) or (n==3)
			point = Geom::Point3d.new(x,y,0)
			point
		end
		def cp_createreducerattributes(param)
			attributes={}
			if param!=nil
				attributes={:Тип         => param[:Тип],             #Тип компонента: переход = "Reducer" = "Переход"
							:Имя            => param[:Имя],             #Наименование перехода для спецификации
							:Материал       => param[:Материал],        #Материал перехода (собственный цвет из настроек слоев)-если нет то 0
							:Стандартный_элемент =>"true"				#элемент является стандартным #-добавка версии 1.4.1(2018)
							}
				attributes = attributes.merge(param) #Объединение хешей
			end
			attributes
		end
		def cp_create_reducer_geometry  #ОТРИСОВЩИК - Создет геометрию перехода по переданным параметрам со внутреннеми стенками
			if @draw_reducer_pts.length>0
				view = @param[:view]
				prevlayer1 = setactivLayer(@layer) if @layer!=nil # Устанавливаем активный слой если задан в параметрах
				model = view.model
				model.start_operation "Создание объекта CoolPipe::CircleReducer"
				entities = model.active_entities
				groupglob=entities.add_group
				entities = groupglob.entities
				group=entities.add_group
				entities = group.entities
				component=groupglob.to_component
				name = @param[:Имя]
				component.name = "Reducer: #{name}"
				component.definition.name="Reducer: #{name}"
				attributes = cp_createreducerattributes(@param)
				mesh1 = Geom::PolygonMesh.new
				mesh2 = Geom::PolygonMesh.new
				pre_pts = nil
				pre_center = nil
				pre_scalepts = nil
				base_circles = []
				future_arc_pts = []
				connector_pts = []
				d1 = @param[:D1].to_f
				s1 = @param[:стенка1].to_f
				d2 = @param[:D2].to_f
				s2 = @param[:стенка2].to_f
				scale1 = (d1-2*s1)/d1 #Коэффициент масштаба 1 для внутренней поверхности трубы относительно наружного большего диаметра
				scale2 = (d2-2*s2)/d2 #Коэффициент масштаба 2 для внутренней поверхности трубы относительно наружного меньшего диаметра
				#создание окрушностей из массива кривых
				reducer_circles_pts = []
				for i in 0..(@draw_reducer_pts[0].length-1)
					vncircle = []
					for j in 0..(@draw_reducer_pts.length-1)
						vncircle << @draw_reducer_pts[j][i] if @draw_reducer_pts[j][i]!=nil
					end
					reducer_circles_pts << vncircle if vncircle!=[]
				end
				#создание геометрии перехода
				for j in 0..(reducer_circles_pts.length-1)
					pts = reducer_circles_pts[j] #pts - точки опорных окружностей сегментов
					if pre_pts!=nil
						if pts!=pre_pts
							for i in 0..(pts.length-2)
								point1 = pts[i]
								point2 = pts[i+1]
								point3 = pre_pts[i+1]
								point4 = pre_pts[i]
								mesh1.add_polygon point1, point2, point3, point4
							end
						end
						pre_pts = pts
					else
						pre_pts = pts
					end
					#Далее ищем точки для осевой линии
					bbox = Geom::BoundingBox.new
					bbox = bbox.add pts
					center = bbox.center
					future_arc_pts << center #Собираем опорные точки будущей осевой линии перехода
					#Далее получаем полигоны внутренней поверхности перехода
					scale_transform1 = Geom::Transformation.scaling center, scale1 #смысл: изменение расстояния до точки путем масштабирования (относительно центра pts окружности)
					scale_transform2 = Geom::Transformation.scaling center, scale2 # -//-
					scale_pts = pts.collect{|pt| #получаем массив точек внутренней окружности
						if j<(reducer_circles_pts.length-2)
							pt.transform scale_transform1
						else
							pt.transform scale_transform2
						end
					}
					base_circles << scale_pts if (j==0)or(j==reducer_circles_pts.length-1)
					if pre_scalepts!=nil
						if scale_pts!=pre_scalepts
							for i in 0..(scale_pts.length-2)
								point1 = scale_pts[i]
								point2 = scale_pts[i+1]
								point3 = pre_scalepts[i+1]
								point4 = pre_scalepts[i]
								mesh2.add_polygon point1, point2, point3, point4 #строим полигоны внутреней поверхности перехода
							end
						end
						pre_scalepts = scale_pts
					else
						pre_scalepts = scale_pts
					end
				end
				puts "#{$coolpipe_langDriver["Количество полигонов составляет"]} #{mesh1.count_polygons+mesh2.count_polygons} #{$coolpipe_langDriver["шт"]}"
				entities.add_faces_from_mesh mesh1
				entities.add_faces_from_mesh mesh2
				entities.each{|face|;face.reverse! if (face.class==Sketchup::Face)}
				#Рисуем заглушки для концов перехода
				case @param[:typeconstruction]
					when "concentric"
						circle1 = []; circle2 = []; pts = []
						@draw_reducer_pts.each{|curve|
							circle1 << curve[0]
							circle2 << curve[curve.length-1]
						}
						pts << Geom::BoundingBox.new.add(circle1).center
						pts << Geom::BoundingBox.new.add(circle2).center
						vec1 = pts[1].vector_to pts[0]
						connector1 = entities.add_cpoint(pts[0])
						set_connector_point(connector1,vec1,@param[:D1],@param[:стенка1]) #Коннектор 1
						vec2 = pts[0].vector_to pts[1]
						connector2 = entities.add_cpoint(pts[1])
						set_connector_point(connector2,vec2,@param[:D2],@param[:стенка2]) #Коннектор 2
						face1 = entities.add_face circle1
						face2 = entities.add_face circle2
						face3 = (entities.add_face base_circles[0]).erase! if base_circles[0]!=nil
						face4 = (entities.add_face base_circles[1]).erase! if base_circles[1]!=nil
						entities.add_line pts
					when "eccentric"
						entities.add_face @draw_reducer_pts[0]
						connector1 = entities.add_cpoint(Geom::BoundingBox.new.add(@draw_reducer_pts[0]).center)
						entities.add_face @draw_reducer_pts[@draw_reducer_pts.length-1]
						connector2 = entities.add_cpoint(Geom::BoundingBox.new.add(@draw_reducer_pts[@draw_reducer_pts.length-1]).center)
						plane = Geom.fit_plane_to_points @draw_reducer_pts[@draw_reducer_pts.length-1] #Плоскость образованная вторым концом отвода (меньшим)
						projected_point = connector1.position.project_to_plane plane #Проекция на полученную плоскоть "первого" коннектора
						vec1 = projected_point.vector_to connector1.position
						vec2 = connector1.position.vector_to projected_point
						set_connector_point(connector1,vec1,@param[:D1],@param[:стенка1]) #Коннектор 1
						set_connector_point(connector2,vec2,@param[:D2],@param[:стенка2]) #Коннектор 2
						entities.add_curve future_arc_pts #рисуем осевую линию
				end
				cp_setattributes(attributes,component)
				setactivLayer(prevlayer1) if prevlayer1!=nil #Восстанавливаем исходный слой
				component.material = @material if @material!=nil
				model.commit_operation
				puts "#{$coolpipe_langDriver["Начерчен: "]} #{name}"
			end
			component
		end
		def cp_create_cylindr_geometry  #ОТРИСОВЩИК - Создет геометрию перехода по переданным параметрам
			if @draw_reducer_pts.length>0
				view = @param[:view]
				prevlayer1 = setactivLayer(@layer) if @layer!=nil # Устанавливаем активный слой если задан в параметрах
				model = view.model
				model.start_operation "Создание объекта CoolPipe::CircleReducer"
				entities = model.active_entities
				groupglob=entities.add_group
				entities = groupglob.entities
				group=entities.add_group
				entities = group.entities
				component=groupglob.to_component
				name = @param[:Имя]
				component.name = "Reducer: #{name}"
				component.definition.name="Reducer: #{name}"
				attributes = cp_createreducerattributes(@param)
				mesh = Geom::PolygonMesh.new
				pre_pts = nil
				pre_center = nil
				future_arc_pts = []
				connector_pts = []
				@draw_reducer_pts.each {|pts| #pts - точки опорных окружностей сегментов
					if pre_pts!=nil
						if pts!=pre_pts
							for i in 0..(pts.length-2)
								point1 = pts[i]
								point2 = pts[i+1]
								point3 = pre_pts[i+1]
								point4 = pre_pts[i]
								mesh.add_polygon point1, point2, point3, point4
							end
						end
						pre_pts = pts
					else
						pre_pts = pts
					end
					#Далее ищем точки для осевой линии
					bbox = Geom::BoundingBox.new
					bbox = bbox.add pts
					center = bbox.center
					future_arc_pts << center #Собираем опорные точки будущей осевой линии перехода
				}
				puts "#{$coolpipe_langDriver["Количество полигонов составляет"]} #{mesh.count_polygons} #{$coolpipe_langDriver["шт"]}"
				entities.add_faces_from_mesh mesh
				entities.each{|face|;face.reverse! if (face.class==Sketchup::Face)and(@param[:typeconstruction]!="concentric")}
				#Рисуем заглушки для концов перехода
				case @param[:typeconstruction]
					when "concentric"
						circle1 = []; circle2 = []; pts = []
						@draw_reducer_pts.each{|curve|
							circle1 << curve[0]
							circle2 << curve[curve.length-1]
						}
						pts << Geom::BoundingBox.new.add(circle1).center
						pts << Geom::BoundingBox.new.add(circle2).center
						vec1 = pts[1].vector_to pts[0]
						connector1 = entities.add_cpoint(pts[0])
						set_connector_point(connector1,vec1,@param[:D1],@param[:стенка1]) #Коннектор 1
						vec2 = pts[0].vector_to pts[1]
						connector2 = entities.add_cpoint(pts[1])
						set_connector_point(connector2,vec2,@param[:D2],@param[:стенка2]) #Коннектор 2
						face1 = entities.add_face circle1
						face2 = entities.add_face circle2
						entities.add_line pts
					when "eccentric"
						entities.add_face @draw_reducer_pts[0]
						connector1 = entities.add_cpoint(Geom::BoundingBox.new.add(@draw_reducer_pts[0]).center)
						entities.add_face @draw_reducer_pts[@draw_reducer_pts.length-1]
						connector2 = entities.add_cpoint(Geom::BoundingBox.new.add(@draw_reducer_pts[@draw_reducer_pts.length-1]).center)
						plane = Geom.fit_plane_to_points @draw_reducer_pts[@draw_reducer_pts.length-1] #Плоскость образованная вторым концом перехода (меньшим)
						projected_point = connector1.position.project_to_plane plane #Проекция на полученную плоскоть "первого" коннектора
						vec1 = projected_point.vector_to connector1.position
						vec2 = connector1.position.vector_to projected_point
						set_connector_point(connector1,vec1,@param[:D1],@param[:стенка1]) #Коннектор 1
						set_connector_point(connector2,vec2,@param[:D2],@param[:стенка2]) #Коннектор 2
						entities.add_curve future_arc_pts #рисуем осевую линию
				end
				cp_setattributes(attributes,component)
				setactivLayer(prevlayer1) if prevlayer1!=nil #Восстанавливаем исходный слой
				component.material = @material if @material!=nil
				model.commit_operation
				puts "#{$coolpipe_langDriver["Начерчен: "]} #{name}"
			end
			component
		end
	end #class ToolDrawReducer < ToolDrawElement
	######
	class ToolDrawTee     < ToolDrawElement  #Инструмент отрисовки тройника
		def initialize(param,redraw = false)
			super(param)
			#@param = param
			@name_connect = ""
			@tee_dots = []
			generate_tee_dots
			Sketchup::set_status_text($coolpipe_langDriver["Необходимо выбрать место присоединения тройника"], SB_PROMPT) if redraw==false
			@user_change_angle = false
			generate_tee_dots
			if redraw!=false #Флаг, указывающий что требуется перерисовка тройника (значения либо false по умолчанию, либо предыдущий компонент)
				transform = redraw.transformation #Копируем трансформации из существующего объекта
				@draw_tee_pts = @tee_dots.collect{|tube|;tube.collect{|dots|;dots.collect{|pt|;pt.transform(transform)}}} #Для рисования сетки тройника
				#cp_create_cylindr_geometry
			end
		end
		def getExtents                                   #Указывает Sketchup границы рисования для View
			bounds = Sketchup.active_model.bounds
			@draw_tee_pts.each{|dots|;dots.each{|pts|;pts.each{|pt|;bounds.add(pt)}}} if @draw_tee_pts!=nil
			@angle_panel_dots.each{|pt|;bounds.add(pt)} if @angle_panel_dots!=nil
			return bounds
		end
		def enableVCB?                                   #Разрешение/Запрещение пользовательского ввода
			if(@state==STATE_SELECT_FIRST_POINT);enable=false;else;enable=true;end
			return enable
		end
		def onMouseMove(flags, x, y, view)               #Событие возникает при перемещении указателя мыши
			@param[:view]=view
			view.model.selection.clear #Если что-то выделено - снять выделение
			case @state
				when STATE_SELECT_FIRST_POINT
					tooltip = view.tooltip = $coolpipe_langDriver["Необходимо выбрать место присоединения тройника"]
					onMouseMove_StateSelectFirstPoint(flags, x, y, view)
				when STATE_SET_ANGLE
					onMouseMove_StateSetAngle(flags, x, y, view)
			end
			view.invalidate
		end
		def onMouseMove_StateSelectFirstPoint(flags, x, y, view)#Обработчик движения мыши при выборе точки расположения тройника (перемещение сетки)
			@x=x;@y=y
			@ip.pick view, x, y
			view.invalidate if(@ip.display?)
			ph = view.pick_helper
			ph.do_pick x,y
			component = ph.best_picked
			if component!=nil
				if Sketchup::CoolPipe::cp_iscpcomponent?(component)  # Указатель мыши над компонентом CoolPipeComponent
					@drawconnector=true
					trans = component.transformation
					where_connector(component,x,y,view,trans)
					if (@connector_vector!=nil)and(@connector_point!=nil)
						@transform_point = Geom::Transformation.new @connector_point,@connector_vector
						@draw_tee_pts = @tee_dots.collect{|tube|;tube.collect{|dots|;dots.collect{|pt|;pt.transform(@transform_point)}}} if @tee_dots!=nil #Для рисования сетки тройника
						@connector_point = (Geom::Point3d.new).transform(@transform_point)
						@tee_vector = (Geom::Vector3d.new 1,0,0).transform(@transform_point)
					end
				else
					@drawconnector = false
					@transform_point = Geom::Transformation.new @ip.position
					@connector_point = (Geom::Point3d.new).transform(@transform_point)
					@connector_vector = Geom::Vector3d.new 0,0,1
					@tee_vector = (Geom::Vector3d.new 1,0,0).transform(@transform_point)
					@draw_tee_pts = @tee_dots.collect{|tube|;tube.collect{|dots|;dots.collect{|pt|;pt.transform(@transform_point)}}} if @tee_dots!=nil #Для рисования сетки тройника
				end
			end
		 end
		def onMouseMove_StateSetAngle(flags, x, y, view) #Обработчик движения указателя мыши при выборе угла вращения вокруг точки вставки
			########
			#1. Выбрать 4 точки окружности (панели вращения) - получить массив этих точек (соответствуют началам квадрантов)
			#2. Спроецировать на экран точки по п.1,точку центра этой окружности, и точку мыши
			#3. Вычислить 5(1+4) векторов до мыши и до опорных точек квадрантов
			#4. Вычислить 4 угла по векторам: квадранты и мышь + сортировка по возрастанию
			#5. Найти 2 первых индекса минимальных углов - это будут те координаты квадрантов между которыми находится мышь
			#6. Определим квадрант расположения указателя мыши по ближайшим двум точкам и вычисляем реальный угол от 0-359 градусов
			#7. Повернем отображаемые сетки на найденный угол
			########
			angle=get_angle_mouse_connector(flags, x, y, view) # 1 - 6
			anchorangle = getAnchorAngle(view,x,y)
			if anchorangle!=nil
				anchorangle = anchorangle - 180 if (@param[:typeconnect]=="centerconnect") and ((anchorangle>=90)and(anchorangle<270))
				angle = anchorangle.degrees
			else
				angle = angle - Math::PI if (@param[:typeconnect]=="centerconnect") and ((angle>=90.degrees)and(angle<270.degrees))
			end
			@ip2.pick view, x, y
			view.tooltip = @ip2.tooltip if( @ip2.valid? ) #отслеживание привязок по сторонней геометрии
			if @user_change_angle == false
				angle_grad = (angle.radians).to_i
				str_angle = angle_grad.to_s
				Sketchup.vcb_value= str_angle + "°" #Печатаем найденный угол в зону контроля значения (в градусах)
				@rot_trans = Geom::Transformation.rotation @connector_point, @connector_vector, angle #7
				multi_trans = @rot_trans*@transform_point
				@draw_tee_pts = @tee_dots.collect{|tube|;tube.collect{|dots|;dots.collect{|pt|;pt.transform(multi_trans)}}}#7 Для рисования сетки тройника
				@tee_direct_din = @tee_direct.collect {|pt|;pt.transform(multi_trans)}
			end
		end
		def onUserText(text, view)                       #Обработка пользовательского ввода значений углов
			begin
				value = text.to_i
			rescue
				UI.beep
				puts $coolpipe_langDriver["Не могу конвертировать в целочисленный градус"]+" "+text
				value = nil
				Sketchup::set_status_text "", SB_VCB_VALUE
			end
			return if (value==nil)
			angle = value.degrees
			@user_change_angle = true
			angle_grad = value
			str_angle = angle_grad.to_s
			Sketchup.vcb_value= str_angle + "°" #Печатаем найденный угол в зону контроля значения (в градусах)
			@rot_trans = Geom::Transformation.rotation @connector_point, @connector_vector, angle #7
			@draw_tee_pts = @tee_dots.collect{|tube|;tube.collect{|dots|;dots.collect{|pt|;pt.transform(@transform_point).transform(@rot_trans)}}} #7 Для рисования сетки тройника
			@tee_direct_din = @tee_direct.collect {|pt|;pt.transform(@transform_point).transform(@rot_trans)}
			cp_create_tee_geometry     if $cp_vnGeom==true
			cp_create_cylindr_geometry if $cp_vnGeom==false
			Sketchup.active_model.select_tool nil
		end
		def onLButtonDown(flags, x, y, view)
			#creategeometry(x, y, view)
			case @state
				when STATE_SELECT_FIRST_POINT
					@state = STATE_SET_ANGLE
				when STATE_SET_ANGLE
					cp_create_tee_geometry     if $cp_vnGeom==true
					cp_create_cylindr_geometry if $cp_vnGeom==false
					Sketchup.active_model.select_tool nil
			end
		end
		def creategeometry(x, y, view)
			ph = view.pick_helper #здесь определяю объект над которым мышь находится
			ph.do_pick x,y
			component = ph.best_picked  #это сама труба к которой прилипает отвод
			@face_component = ph.picked_face
			face_component = @face_component #это активная поверхность (в нашем случае это конец трубопровода)
			if face_component!=nil
				connect_attributes = cp_getattributes(component)
				@attributes[:view]=view
				@attributes[:Печать_информации]=true
				@attributes[:D1]=connect_attributes[:D1]
				@attributes[:D2]=connect_attributes[:D2]
				@attributes[:Слой]=connect_attributes[:Слой]
				@attributes[:Материал]=connect_attributes[:Материал]
				xaxes,yaxes,zaxes = cp_get_axes_connector(component,face_component)
				@state = 1
				@attributes[:center] = cp_set_component_transforms(component,face_component.bounds.center) # цент вокруг которого вращать
				@attributes[:xaxes] = xaxes #вектор основания
				@attributes[:yaxes] = yaxes #вектор основания
				@attributes[:zaxes] = zaxes #вектор вокруг которого вращать
				@component = cp_create_tee_geometry(@attributes)
				Sketchup.active_model.select_tool CP_rotate_tool.new(@component,@attributes)
			end
		end
		def generate_tee_dots                    #Создание опорных точек для построения тройника
			d1 = @param[:D1].to_f            #Наружний диаметр большего диаметра тройника
			d2 = @param[:D2].to_f            #Наружний диаметр меньшего диаметра тройника
			l  = @param[:Длина].to_f         #Длина отрезка большего диаметра
			h  = @param[:Высота].to_f        #Длина отрезка меньшего диаметра
			#wall1 = @param[:стенка1].to_f   #Толщина стенки отвода отрезка большего диаметра - ВРЕМЕННО НЕ ИСПОЛЬЗУЕТСЯ
			#wall2 = @param[:стенка2].to_f   #Толщина стенки отвода отрезка меньшего диаметра - ВРЕМЕННО НЕ ИСПОЛЬЗУЕТСЯ
			segm = $cp_segments              #Кол-во сегментов
			circle_dots = []
			delta_angle = 360/segm
			circle_dots1 = generate_arc(d1/2,0,360,delta_angle)#массив точек окружности большего диаметра
			circle_dots2 = generate_arc(d2/2,0,360,delta_angle)#массив точек окружности меньшего диаметра
			tee_vector1 = Geom::Vector3d.new 1,0,0    #вектор направления тройника
			tee_vector2 = Geom::Vector3d.new 0,0,1    #вектор ответвления тройника
			tee_vector3 = Geom::Vector3d.new 0,1,0    #вектор поворота массива @circle_dots2
			tee_dots1 = []                  #Массив массивов окружностей большего диаметра
			tee_dots2 = []                  #Массив массивов окружностей меньшего диаметра
			delta_l = l/4                   #расстояние между окружностями большего диаметра
			delta_h = h/3                   #расстояние между окружностями меньшего диаметра
			transformation1 = Geom::Transformation.rotation [0,0,0], tee_vector3, 90.degrees #Поворот
			transformation2 = Geom::Transformation.new [0,0,l.mm/2]#смещение
			0.step(l,delta_l){|dl|
				transformation3 = Geom::Transformation.new [0,0,dl.mm]#смещение
				tee_dots1 << circle_dots1.collect {|pt|;pt.transform(transformation3)}
			}
			0.step(h,delta_h){|dh|
				transformation4 = Geom::Transformation.new [dh.mm,0,0]#смещение
				tee_dots2 << circle_dots2.collect {|pt|;pt.transform(transformation1).transform(transformation2).transform(transformation4)}
			}
			tee_dots1.compact
			tee_dots2.compact
			@tee_direct = [[0,0,0],[d1.mm,0,0]] #Линия направления тройника (указывает куда ведет ответвление)
			@tee_dots=[tee_dots1,tee_dots2]
			if @param[:typeconnect]=="centerconnect" #В случае привязки тройника стороной ответвления - поворачиваем базовые точки
				pt = [0,0,(l/2).mm]
				vec = Geom::Vector3d.new 0,1,0
				trans1 = Geom::Transformation.rotation pt, vec, 90.degrees
				@tee_dots = @tee_dots.collect.collect{|tube|;tube.collect{|pts|;pts.collect{|pt|;pt.transform(trans1)}}}
				dh = (l/2 - h).mm
				@tee_dots = @tee_dots.collect.collect{|tube|;tube.collect{|pts|;pts.collect{|pt|;pt.offset(tee_vector2.reverse,dh)}}} if dh>0
			end
		end
		def draw(view) #рисует точку присоединения отвода
			i = 0
			case @state
				when STATE_SELECT_FIRST_POINT #Место расположение отвода
						view.draw_points  @connector_point, 10, 1, "red" if (@connector_point!=nil)&&(@connector_vector!=nil)
						view.drawing_color = "Black"
						view.line_stipple = ""
						draw_tee_dots(view) if @draw_tee_pts!=nil
				when STATE_SET_ANGLE
					view.drawing_color = "Black"
					view.line_stipple = ""
					if (@sel_angle_panel!=nil)and(@sel_angle_panel!=[])
						view=view.draw GL_LINE_LOOP, @sel_angle_panel #отрисовка окружности
						draw_tee_dots(view) #отрисовка тройника по заданным характеристикам
						k = 95
						@sel_angle_panel.each{|pt1|  #Отрисовка засечек
							view.line_stipple = ""
							i+=1
							k = k-5
							k = 355 if k<0
							if [4,7,13,16,22,25,31,34,40,43,49,52,58,61,67,70].include?(i)
								pt2 = Geom::Point3d.linear_combination 0.2,@connector_point,0.8,pt1
								vec = pt1.vector_to pt2
								axes = vec.axes
								addAnchorAngle(view,pt2,axes[0],@mx,@my,k)
							elsif [1,10,19,28,37,46,55,64].include?(i)
								pt2 = Geom::Point3d.linear_combination 0.3,@connector_point,0.7,pt1
								vec = pt1.vector_to pt2
								axes = vec.axes
								addAnchorAngle(view,pt2,axes[0],@mx,@my,k)
							else
								pt2 = Geom::Point3d.linear_combination 0.1,@connector_point,0.9,pt1
							end
							view.drawing_color = "black"
							view = view.draw_line pt1,pt2
						}
						view.drawing_color = "Green"
						view=view.draw GL_LINE_LOOP,@tee_direct_din
					end
					view.draw_points  @ip2.position, 3, 1, "blue" if ( @ip2.valid? ) #Отображение точки привязки
			end
		end
		def draw_tee_dots(view)                        #Отрисовка сетки будущего тройника
			draw_array_circlepts(@draw_tee_pts[0],view)
			draw_array_circlepts(@draw_tee_pts[1],view)
		end
		def drawconnector(component,face_component,view) #Рисует коннектор
			if (face_component!=nil) && (component!=nil)
				connect_attributes = cp_getattributes(component)
				@name_connect= connect_attributes[:Имя] #имя объекта
				@dn_connect= connect_attributes[:D1]
				tr1 = component.definition.entities[0].transformation #обратная трансформация группы для получения абсолютных координат
				tr2 = component.transformation #обратная трансформация компонента для получения абсолютных координат
				multi_trans = tr2*tr1
				tooltip = view.tooltip = $coolpipe_langDriver["Присоединить тройник к"]+": "+@name_connect
				@face_component = face_component
				pt1 = face_component.bounds.center #получение точки присоединения отвода
				pt1 = pt1.transform! multi_trans
				@pt_startelbow = pt1.clone
			else
				reset(view)
			end
		end
		def cp_createteeattributes(param)
			attributes={}
			if param!=nil
				attributes={:Тип         => param[:Тип],          # Тип компонента: переход = "Tee" = "Тройник"
							:Имя            => param[:Имя],             # Наименование перехода для спецификации
							:Материал       => param[:Материал],        # Материал перехода (собственный цвет из настроек слоев)-если нет то 0
							:Стандартный_элемент =>"true"				     #элемент является стандартным #-добавка версии 1.4.1(2018)
							}
				attributes = attributes.merge(param) # Объединение хешей
			end
			attributes
		end
		def cp_create_tee_geometry               # ОТРИСОВЩИК 4 - Создет геометрию тройника по переданным параметрам c внутренней геометрии
			param =@param
			if @draw_tee_pts.length>0
				view = @param[:view]
				prevlayer1 = setactivLayer(@layer) if @layer!=nil # Устанавливаем активный слой если задан в параметрах
				model = view.model  #начало построение Тройника
				model.start_operation "Создание объекта CoolPipe::CircleTee"
				entities = model.active_entities
				groupglob=entities.add_group
				entities = groupglob.entities
				group1=entities.add_group
				group2=entities.add_group
				group3=entities.add_group
				entities1 = group1.entities #Больший диаметр Solid
				entities2 = group2.entities #Меньший диаметр Solid
				entities3 = group3.entities #Осевые линии и коннекторы
				if (Sketchup.is_pro?)
					group4=entities.add_group
					group5=entities.add_group
					entities4 = group4.entities #Больший диаметр Solid для обрезки в Pro версиях SU
					entities5 = group5.entities #Меньший диаметр Solid для обрезки в Pro версиях SU
				end
				component=groupglob.to_component
				name = @param[:Имя]
				component.name = "Tee: #{name}"
				component.definition.name="Tee: #{name}"
				attributes = cp_createteeattributes(@param)
				mesh = [(Geom::PolygonMesh.new),(Geom::PolygonMesh.new)] # [Главная труба (большего диаметра); Труба ответвления (меньшего диаметра)]
				mesh1 = Geom::PolygonMesh.new
				mesh2 = Geom::PolygonMesh.new
				mesh3 = Geom::PolygonMesh.new #Больший диаметр внутр
				mesh4 = Geom::PolygonMesh.new #Меньший диаметр внутр
				pre_pts = nil
				pre_scalepts = nil
				scale_pts = [[],[]]
				d1 = @param[:D1].to_f
				s1 = @param[:стенка1].to_f
				d2 = @param[:D2].to_f
				s2 = @param[:стенка2].to_f
				scale1 = (d1-2*s1)/d1 #Коэффициент масштаба 1 для внутренней поверхности трубы относительно наружного большего диаметра
				scale2 = (d2-2*s2)/d2 #Коэффициент масштаба 2 для внутренней поверхности трубы относительно наружного меньшего диаметра
				#-------------------------------------
				#Построение внешних контуров тройника
				for k in 0..1
					pre_pts=nil
					@draw_tee_pts[k].each {|pts|
						if pre_pts!=nil
							if pts!=pre_pts
								for i in 0..(pts.length-2)
									point1 = pts[i]
									point2 = pts[i+1]
									point3 = pre_pts[i+1]
									point4 = pre_pts[i]
									index_mesh1=mesh1.add_polygon point1, point2, point3, point4 if k==0
									index_mesh2=mesh2.add_polygon point1, point2, point3, point4 if k==1
								end
							end
							pre_pts = pts
						else
							pre_pts = pts
						end
					}
				end
				#-------------------------------------
				#Получение внутренних точек окружностей тройника
				for k in 0..1
					i=0
					@draw_tee_pts[k].each {|pts|
						if pts!=nil
							bbox = Geom::BoundingBox.new
							bbox = bbox.add pts
							center = bbox.center #точки для центра масштабирования нар поверхности к внутренней
							scale_transform = Geom::Transformation.scaling center, scale1 if k==0 #Больший диаметр
							scale_transform = Geom::Transformation.scaling center, scale2 if k==1 #Больший диаметр
							scale_pts[k][i] = pts.collect{|pt|;pt.transform scale_transform} #получаем массив точек внутренней окружности
							i+=1
						end
					}
				end
				#-------------------------------------
				#Построение внутренних контуров тройника
				for k in 0..1
					pre_pts=nil
					scale_pts[k].each {|pts|
						if pre_pts!=nil
							if pts!=pre_pts
								for i in 0..(pts.length-2)
									point1 = pts[i]
									point2 = pts[i+1]
									point3 = pre_pts[i+1]
									point4 = pre_pts[i]
									index_mesh3=mesh3.add_polygon point1, point2, point3, point4 if k==0
									index_mesh4=mesh4.add_polygon point1, point2, point3, point4 if k==1
								end
							end
							pre_pts = pts
						else
							pre_pts = pts
						end
					}
				end
				#-------------------------------------
				puts "#{$coolpipe_langDriver["Количество полигонов составляет"]} #{mesh1.count_polygons+mesh2.count_polygons} #{$coolpipe_langDriver["шт"]}"
				entities1.add_faces_from_mesh mesh1
				entities1.add_faces_from_mesh mesh3
				face11 = entities1.add_face @draw_tee_pts[0][0]
				face12 = entities1.add_face @draw_tee_pts[0][@draw_tee_pts[0].length-1]
				face21 = entities1.add_face scale_pts[0][0]
				face22 = entities1.add_face scale_pts[0][scale_pts[0].length-1]
				face21.erase!;face22.erase!
				entities2.add_faces_from_mesh mesh2
				entities2.add_faces_from_mesh mesh4
				face31 = entities2.add_face @draw_tee_pts[1][@draw_tee_pts[1].length-1]
				face32 = entities2.add_face @draw_tee_pts[1][0] #Не является коннектором
				face41 = entities2.add_face scale_pts[1][scale_pts[1].length-1]
				face42 = entities2.add_face scale_pts[1][0]
				face41.erase!;face42.erase!
				if (Sketchup.is_pro?)
					entities4.add_faces_from_mesh mesh3
					face5 = entities4.add_face scale_pts[0][0]
					face6 = entities4.add_face scale_pts[0][scale_pts[0].length-1]
					group4.subtract(group2)
					#------
					entities5.add_faces_from_mesh mesh4
					face5 = entities5.add_face scale_pts[1][scale_pts[1].length-1]
					face6 = entities5.add_face scale_pts[1][0]
					group5.subtract(group1)
				end
				connector1 = entities3.add_cpoint(Geom::BoundingBox.new.add(@draw_tee_pts[0][0]).center)
				connector2 = entities3.add_cpoint(Geom::BoundingBox.new.add(@draw_tee_pts[0][@draw_tee_pts[0].length-1]).center)
				connector3 = entities3.add_cpoint(Geom::BoundingBox.new.add(@draw_tee_pts[1][@draw_tee_pts[1].length-1]).center)
				point4 = entities3.add_cpoint(Geom::BoundingBox.new.add(@draw_tee_pts[1][0]).center)
				entities3.add_curve connector1.position,connector2.position #рисуем осевую линию 1
				entities3.add_curve connector3.position,point4.position     #рисуем осевую линию 2
				vec1 = connector1.position.vector_to connector2.position
				vec2 = connector2.position.vector_to connector1.position
				vec3 = point4.position.vector_to connector3.position
				set_connector_point(connector1,vec1,@param[:D1],@param[:стенка1]) #Коннектор 1
				set_connector_point(connector2,vec2,@param[:D1],@param[:стенка1]) #Коннектор 2
				set_connector_point(connector3,vec3,@param[:D2],@param[:стенка2]) #Коннектор 3
				behavior = component.definition.behavior #Для ограничения вариантов масштабирования объекта
				mask = (1<<0)+(1<<1)+(1<<2)+(1<<3)+(1<<4)+(1<<5)+(1<<6) #запрет масштабирования
				behavior.no_scale_mask = mask #Применяем маску
				cp_setattributes(attributes,component)
				setactivLayer(prevlayer1) if prevlayer1!=nil #Восстанавливаем исходный слой
				component.material = @material if @material!=nil
				model.commit_operation
				puts "#{$coolpipe_langDriver["Начерчен: "]}#{name}"
			end
			component
		end
		def cp_create_cylindr_geometry           # ОТРИСОВЩИК 4 - Создет геометрию тройника по переданным параметрам
			param =@param
			if @draw_tee_pts.length>0
				view = @param[:view]
				prevlayer1 = setactivLayer(@layer) if @layer!=nil # Устанавливаем активный слой если задан в параметрах
				model = view.model  #начало построение Тройника
				model.start_operation "Создание объекта CoolPipe::CircleTee"
				entities = model.active_entities
				groupglob=entities.add_group
				entities = groupglob.entities
				group1=entities.add_group
				group2=entities.add_group
				group3=entities.add_group
				group4=entities.add_group if (Sketchup.is_pro?)
				entities1 = group1.entities #Больший диаметр Solid
				entities2 = group2.entities #Меньший диаметр Solid
				entities3 = group3.entities #Осевые линии и коннекторы
				entities4 = group4.entities if (Sketchup.is_pro?) #Больший диаметр Solid для обрезки в Pro версиях SU
				component=groupglob.to_component
				name = @param[:Имя]
				component.name = "Tee: #{name}"
				component.definition.name="Tee: #{name}"
				attributes = cp_createteeattributes(@param)
				mesh = [(Geom::PolygonMesh.new),(Geom::PolygonMesh.new)] # [Главная труба (большего диаметра); Труба ответвления (меньшего диаметра)]
				mesh1 = Geom::PolygonMesh.new
				mesh2 = Geom::PolygonMesh.new
				pre_pts = nil
				for k in 0..1
					@draw_tee_pts[k].each {|pts|
						if pre_pts!=nil
							if pts!=pre_pts
								for i in 0..(pts.length-2)
									point1 = pts[i]
									point2 = pts[i+1]
									point3 = pre_pts[i+1]
									point4 = pre_pts[i]
									index_mesh1=mesh1.add_polygon point1, point2, point3, point4 if k==0
									index_mesh2=mesh2.add_polygon point1, point2, point3, point4 if k==1
								end
							end
							pre_pts = pts
						else
							pre_pts = pts
						end
					}
					pre_pts = nil
				end
				puts "#{$coolpipe_langDriver["Количество полигонов составляет"]} #{mesh1.count_polygons+mesh2.count_polygons} #{$coolpipe_langDriver["шт"]}"
				entities1.add_faces_from_mesh mesh1
				# Рисуем коннекторы
				face1 = entities1.add_face @draw_tee_pts[0][0]
				face2 = entities1.add_face @draw_tee_pts[0][@draw_tee_pts[0].length-1]
				entities2.add_faces_from_mesh mesh2
				face3 = entities2.add_face @draw_tee_pts[1][@draw_tee_pts[1].length-1]
				face4 = entities2.add_face @draw_tee_pts[1][0] #Не является коннектором
				if (Sketchup.is_pro?)
					entities4.add_faces_from_mesh mesh1
					face5 = entities4.add_face @draw_tee_pts[0][0]
					face6 = entities4.add_face @draw_tee_pts[0][@draw_tee_pts[0].length-1]
					group4.subtract(group2)
				end
				connector1 = entities3.add_cpoint(Geom::BoundingBox.new.add(@draw_tee_pts[0][0]).center)
				connector2 = entities3.add_cpoint(Geom::BoundingBox.new.add(@draw_tee_pts[0][@draw_tee_pts[0].length-1]).center)
				connector3 = entities3.add_cpoint(Geom::BoundingBox.new.add(@draw_tee_pts[1][@draw_tee_pts[1].length-1]).center)
				point4 = entities3.add_cpoint(Geom::BoundingBox.new.add(@draw_tee_pts[1][0]).center)
				entities3.add_curve connector1.position,connector2.position #рисуем осевую линию 1
				entities3.add_curve connector3.position,point4.position     #рисуем осевую линию 2
				vec1 = connector1.position.vector_to connector2.position
				vec2 = connector2.position.vector_to connector1.position
				vec3 = point4.position.vector_to connector3.position
				set_connector_point(connector1,vec1,@param[:D1],@param[:стенка1]) #Коннектор 1
				set_connector_point(connector2,vec2,@param[:D1],@param[:стенка1]) #Коннектор 2
				set_connector_point(connector3,vec3,@param[:D2],@param[:стенка2]) #Коннектор 3
				behavior = component.definition.behavior #Для ограничения вариантов масштабирования объекта
				mask = (1<<0)+(1<<1)+(1<<2)+(1<<3)+(1<<4)+(1<<5)+(1<<6) #запрет масштабирования
				behavior.no_scale_mask = mask #Применяем маску
				cp_setattributes(attributes,component)
				setactivLayer(prevlayer1) if prevlayer1!=nil #Восстанавливаем исходный слой
				component.material = @material if @material!=nil
				model.commit_operation
				puts "#{$coolpipe_langDriver["Начерчен: "]}#{name}"
			end
			component
		end
	end #class ToolDrawTee < ToolDrawElement
	######
	class ToolDrawCap     < ToolDrawElement  #Инструмент отрисовки заглушки
		def initialize()
			super()
			@name_connect    = ""
    		@attributes = nil
    		@niltool=false
    		@state = STATE_SELECT_FIRST_POINT
		end
		def reset(view)                                  #Сброс настроек
			super(view)
			Sketchup::set_status_text($coolpipe_langDriver["Указать место расположения заглушки"], SB_PROMPT)
			@drawn = false
			@connector_vector=nil
			@draw_cap_pts = []
		end
		def getExtents                                   #Указывает Sketchup границы рисования для View
			bounds = Sketchup.active_model.bounds
			@draw_cap_pts.each{|dots|;dots.each{|pt|;bounds.add(pt)}} if @draw_cap_pts!=nil
			return bounds
		end
		def enableVCB?;return false;end  #запрещаем пользовательский ввод
		def onMouseMove(flags, x, y, view)               #Событие возникает при перемещении указателя мыши
			@param[:view]=view
			view.model.selection.clear #Если что-то выделено - снять выделение
			case @state
				when STATE_SELECT_FIRST_POINT
					onMouseMove_StateSelectFirstPoint(flags, x, y, view)
			end
			view.invalidate
		end
		def onMouseMove_StateSelectFirstPoint(flags, x, y, view)   #Обработчик движения мыши при выборе точки расположения отвода (перемещение сетки)
			@ip.pick view, x, y
			ph = view.pick_helper
			ph.do_pick x,y
			component = ph.best_picked
			if component!=nil
				if Sketchup::CoolPipe::cp_iscpcomponent?(component)  # Указатель мыши над компонентом CoolPipeComponent
					create_cap_param(ph,x,y,view)
					@drawconnector=true
					trans = component.transformation
					where_connector(component,x,y,view,trans)
					if (@connector_vector!=nil)and(@connector_point!=nil)
						generate_cap_dots
						@transform_point = Geom::Transformation.new @connector_point,@connector_vector
						@draw_cap_pts = @cap_dots.collect{|dots|;dots.collect{|pt|;pt.transform(@transform_point)}} if @cap_dots!=nil #Для рисования сетки заглушки
						@connector_point = (Geom::Point3d.new).transform(@transform_point)
					end
				else
					@connector_vector = nil
					@connector_point = nil
					@drawconnector = false
				end
			end
		end
		def onLButtonDown(flags, x, y, view)             #Нажатие на левую клавишу мыши
			if  @state == STATE_SELECT_FIRST_POINT
				@ip1.pick view, x, y
				if @draw_cap_pts.length>0 #если есть отображение сетки, можно переходить к следующему этапу
					if( @ip1.valid? )
						Sketchup.active_model.select_tool nil
						@param[:view]=view
						cp_create_cap_geometry
					end
					if @drawconnector
						@ip1 = Sketchup::InputPoint.new(@connector_point)
					end
				end
			end
			view.lock_inference
		end
		def create_cap_param(ph,x,y,view)                #Создание параметров заглушки относительно места присоединения
			component = ph.best_picked  #это компонент к которому прилипает заглушка
			face_component = ph.picked_face #это активная поверхность (например конец трубопровода)
			connector_attribute = Sketchup::CoolPipe::cp_getattributes(face_component)
			attributes = Sketchup::CoolPipe::cp_getattributes(component)
			@param[:Тип]           = "Заглушка"
			@param[:ЕдИзм]         = $coolpipe_langDriver["шт"]
			if attributes[:Dнар]!=nil
				@param[:Dнар]      = attributes[:Dнар]
				@param[:стенка]    = attributes[:стенка]
				@param[:Имя]       = $coolpipe_langDriver["Заглушка для труб"]+" Ø#{attributes[:Dнар]}х#{attributes[:стенка]}"
			else
				@param[:Dнар]      = @alt_dn #Альтернативный диаметр для переходов и тройников
				@param[:стенка]    = @alt_st
				@param[:Имя]       = $coolpipe_langDriver["Заглушка для труб"]+" Ø#{@alt_dn}х#{@alt_st}"
			end
			@param[:ГОСТ]          = "Документ"
			@param[:Cегментов]     = $cp_segments
			@param[:typemodel]     = "cyl" #cyl - без внутренней поверхности
			generate_cap_dots
		end
		def generate_cap_dots                            #Создание опорных точек для построения заглушки
			if (@alt_dn==nil) or (@alt_dn==@param[:Dнар])
				diam  = @param[:Dнар].to_f         #Наружний диаметр заглушки
				wall  = @param[:стенка].to_f       #Толщина стенки заглушки
			else
				diam  = @alt_dn.to_f               #Наружний диаметр заглушки
				wall  = @alt_st.to_f               #Толщина стенки заглушки
			end
			segm = @param[:Cегментов].to_i         #Кол-во сегментов
			point = [0,0,0]                        #Точка вокруг которой рисуется заглушка
			vector = [0,1,0]                       #Вектор вокруг которого рисуется заглушка
			h_small = 10.to_f.mm                   #Высота прямой части заглушки 1 сантиметр
			h_big = (diam*0.15).mm+h_small         #Общая высота заглушки
			n_circle = (diam/9).to_i               #Количество концентрических окружностей уменьшающегося диаметра
			n_circle = 10 if n_circle<10
			dh_circle = (h_big-h_small)/n_circle   #Смещение центра окружностей по высоте заглушки
			delta_diam = diam/(n_circle*PI*PI)     #Скорость уменьшения диаметра с каждым новым кольцом
			dynamic_diam = diam                    #Переменная динамического уменьшения диаметра
			dynamic_z = h_small                    #Переменная динамического увеличения высоты расположения окружности
			circle_dots = []
			@cap_dots = []
			segm = $cp_segments if segm<$cp_segments
			delta_angle = 360/segm
			circle_dots = generate_arc(diam/2,0,360,delta_angle)
			@cap_dots << circle_dots                                             #Окружность основания
			p1 = [0,0,h_small]
			transformation = Geom::Transformation.new p1                         #Подъем окружности на высоту h_small
			@cap_dots << circle_dots.collect {|pt|;pt.transform(transformation)} #Окружность перед уменьшением диаметров
			for i in 1..n_circle
				dynamic_diam = dynamic_diam - delta_diam*i
				if dynamic_diam>0
					dynamic_z = dynamic_z + dh_circle
					circle_dots = generate_arc(dynamic_diam/2,0,360,delta_angle)
					p2 = [0,0,dynamic_z]
					transformation = Geom::Transformation.new p2                         #Подъем окружности на высоту dynamic_z
					@cap_dots << circle_dots.collect {|pt|;pt.transform(transformation)} #Окружности c уменьшением диаметра
				end
			end
			@cap_dots.compact
		end
		def draw_cap_dots(view)                          #Отрисовка сетки будущей заглушки
			draw_array_circlepts(@draw_cap_pts,view)
		end
		def draw(view)
			draw_cap_dots(view)
			view.line_stipple = ""
			view.draw_points  @connector_point, 10, 1, "red" if (@connector_point!=nil)&&(@connector_vector!=nil)
		end
		def cp_cap_massa                                 #расчет массы заглушки
			dn = @param[:Dнар].to_f
			st = if (@alt_st==nil) then @param[:стенка].to_f else @alt_st.to_f end
			dv = dn - 2*st;
			rn = dn/2;
			rv = dv/2;
			hsn = 0.15*dn  #Высота шаровой части по наружному диаметру
			hsv = hsn - st #Высота шаровой части по внутреннему диаметру
			vol1 = Math::PI*rn*rn*10 #Расчитывается по формуле цилиндра - объем прямой части заглушки по наружному диаметру
			vol2 = Math::PI*rv*rv*10 #Расчитывается по формуле цилиндра - объем прямой части заглушки по внутреннему диаметру
			vol3 = Math::PI*hsn*hsn*(rn-hsn/3) #Расчитывается по формуле объема шарового сегмента (по наружному диаметру)
			vol4 = Math::PI*hsv*hsv*(rv-hsv/3) #Расчитывается по формуле объема шарового сегмента (по внутреннему диаметру)
			volume = (vol1-vol2)+(vol3-vol4)
			massa = ($cp_elbowPlotnost*volume/1000).to_i.to_f/1000
			massa
		end
		def cp_calculate_cap_area #Расчет площади заглушки для окраски -- #добавлено в 1.4.1(2018)
			dn = @param[:Dнар].to_f/1000
			hs = 0.15*dn  #Высота шаровой части по наружному диаметру
			rn = dn/2;
			s1 = Math::PI*dn*0.01   #Площадь цилиндрической части
			s2 = 2*Math::PI*rn*hs #Площадь шаровой части
			s = Sketchup::CoolPipe::roundf(s1+s2,5)#.round(5)
			s
		end
		def cp_createcapattributes(param)              #создает список атрибутов для Отвода
			attributes={}
			if param!=nil
			apr = @actual_point_rotate
			attributes={:Тип         => "Заглушка",                   #Тип компонента: Заглушка
						:Имя            => "#{param[:Имя]}",                #Наименование для спецификации
						:ЕдИзм          => $coolpipe_langDriver["шт"],      #Единица измерения для спецификации
						:Dнар           => param[:Dнар],
						:стенка         => param[:стенка],
						:ГОСТ           => "Документ",                      #Нормативный документ (из базы)
						:Материал       => param[:Материал],                #Материал трубопровода (собственный цвет из настроек слоев)-если нет то 0
						:typemodel      => "cyl",                           #Тип отрисованного объекта (cyl = цилиндрический, cap = с внутренней геометрией)
						:Площадь			 => cp_calculate_cap_area.to_s,      #Расчет площади заглушки для окраски -- #добавлено в 1.4.1(2018)
						:Стандартный_элемент =>"true"				             #элемент является стандартным #-добавка версии 1.4.1(2018)
						}
			attributes[:Dнар]  = if (@alt_dn==nil) then param[:Dнар]   else @alt_dn end
			attributes[:стенка]= if (@alt_st==nil) then param[:стенка] else @alt_st end
			attributes[:Имя]= $coolpipe_langDriver["Заглушка для труб"]+" Ø#{attributes[:Dнар]}х#{attributes[:стенка]}"
			attributes[:масса] = cp_cap_massa  #Масса единицы для спецификации
			end
			attributes
		end #cp_createelbowattributes(param)
		def cp_create_cap_geometry
			if @draw_cap_pts.length>0
				view = @param[:view]
				prevlayer1 = setactivLayer(@layer) if @layer!=nil # Устанавливаем активный слой если задан в параметрах
				model = view.model
				model.start_operation "Создание объекта CoolPipe::CircleCap"
				entities = model.active_entities
				groupglob=entities.add_group
				entities = groupglob.entities
				group=entities.add_group
				entities = group.entities
				component=groupglob.to_component
				attributes = cp_createcapattributes(@param)
				name =attributes[:Имя]
				component.name = "Cap: #{name}"
				component.definition.name="Cap: #{name}"
				mesh = Geom::PolygonMesh.new
				pre_pts = nil
				pre_center = nil
				connector_pts = []
				@draw_cap_pts.each {|pts| #pts - точки опорных окружностей сегментов
					if pre_pts!=nil
						if pts!=pre_pts
							for i in 0..(pts.length-2)
								point1 = pts[i]
								point2 = pts[i+1]
								point3 = pre_pts[i+1]
								point4 = pre_pts[i]
								mesh.add_polygon point1, point2, point3, point4
							end
						end
						pre_pts = pts
					else
						pre_pts = pts
					end
				}
				count_mesh = mesh.count_polygons	#Подсчет полигонов наружной поверхности заглушки
				entities.add_faces_from_mesh mesh
				entities.each{|face|;face.reverse! if face.class==Sketchup::Face}
				face1 = entities.add_face @draw_cap_pts[0]
				face2 = entities.add_face @draw_cap_pts[@draw_cap_pts.length-1]
				if $cp_vnGeom #здесь нужно нарисовать внутреннюю геометрию заглушки если true
					#####################
					d = attributes[:Dнар].to_f
					s = attributes[:стенка].to_f
					#puts "d=#{d}; s=#{s}"
					scale = (d-2*s)/d         #Коэффициент масштаба для внутренней поверхности заглушки относительно наружного
					#puts "scale = #{scale}"
					scale_pts = @draw_cap_pts.collect{|pts|
						bbox = Geom::BoundingBox.new
						bbox = bbox.add pts
						center = bbox.center
						scale_transform = Geom::Transformation.scaling center, scale
						pts.collect{|pt| #получаем массив точек внутренней окружности
							pt.transform scale_transform #Масштабируем точки
						}
					}
					###
					mesh = Geom::PolygonMesh.new
					pre_pts = nil
					pre_center = nil
					connector_pts = []
					for i in 0..scale_pts.length-2
						pts = scale_pts[i] #pts - точки опорных окружностей сегментов
						if pre_pts!=nil
							if pts!=pre_pts
								for j in 0..(pts.length-2)
									point1 = pts[j]
									point2 = pts[j+1]
									point3 = pre_pts[j+1]
									point4 = pre_pts[j]
									mesh.add_polygon point1, point2, point3, point4
								end
							end
							pre_pts = pts
						else
							pre_pts = pts
						end
					end
					count_mesh += mesh.count_polygons #Подсчет полигонов наружной + внутренней поверхности заглушки
					entities.add_faces_from_mesh mesh
					face3 = entities.add_face scale_pts[0]
					face4 = entities.add_face scale_pts[scale_pts.length-2]
					face3.hidden = true
					#####################
				end
				puts "#{$coolpipe_langDriver["Количество полигонов составляет"]} #{count_mesh} #{$coolpipe_langDriver["шт"]}"
				point1=entities.add_cpoint(Geom::BoundingBox.new.add(@draw_cap_pts[0]).center)
				pts = [point1.position,Geom::BoundingBox.new.add(@draw_cap_pts[@draw_cap_pts.length-1]).center]
				entities.add_line pts #осевая линия
				set_connector_point(point1,face1.normal.reverse!)
				entities.each{|face|;face.reverse! if face.class==Sketchup::Face}
				behavior = component.definition.behavior #Для ограничения вариантов масштабирования объекта
				mask = (1<<0)+(1<<1)+(1<<2)+(1<<3)+(1<<4)+(1<<5)+(1<<6) #запрет масштабирования
				behavior.no_scale_mask = mask #Применяем маску
				cp_setattributes(attributes,component)
				setactivLayer(prevlayer1) if prevlayer1!=nil #Восстанавливаем исходный слой
				component.material = @material if @material!=nil
				model.commit_operation
				puts "#{$coolpipe_langDriver["Начерчена: "]}#{name}"
			end
			component
		end
	end #class ToolDrawCap < ToolDrawElement
	######
	class ToolDrawFlange  < ToolDrawElement  #Инструмент отрисовки фланца
		def initialize(param)
			super(param)
			@name_connect    = ""
			@attributes = nil
			@niltool=false
			@state = STATE_SELECT_FIRST_POINT
			generate_flange_dots
			#puts "@param=#{@param}"
		end
		def reset(view)                                  #Сброс настроек
			super(view)
			Sketchup::set_status_text($coolpipe_langDriver["Указать место расположения фланца"], SB_PROMPT)
			@drawn = false
			@connector_vector=nil
			@draw_flange_pts = []
			@draw_flange_bolts = []
		end
		def getExtents                                   #Указывает Sketchup границы рисования для View
			bounds = Sketchup.active_model.bounds
			@draw_flange_pts.each{|dots|;dots.each{|pt|;bounds.add(pt)}} if @draw_flange_pts!=nil
			return bounds
		end
		def enableVCB?;return false;end  #запрещаем пользовательский ввод
		def onMouseMove(flags, x, y, view)               #Событие возникает при перемещении указателя мыши
			@param[:view]=view
			view.model.selection.clear #Если что-то выделено - снять выделение
			case @state
				when STATE_SELECT_FIRST_POINT
					onMouseMove_StateSelectFirstPoint(flags, x, y, view)
			end
			view.invalidate
		end
		def onMouseMove_StateSelectFirstPoint(flags, x, y, view)   #Обработчик движения мыши при выборе точки расположения отвода (перемещение сетки)
			@ip.pick view, x, y
			ph = view.pick_helper
			ph.do_pick x,y
			component = ph.best_picked
			if component!=nil
				if Sketchup::CoolPipe::cp_iscpcomponent?(component)  # Указатель мыши над компонентом CoolPipeComponent
					@drawconnector=true
					trans = component.transformation
					where_connector(component,x,y,view,trans)
					if (@connector_vector!=nil)and(@connector_point!=nil)
						generate_flange_dots
						@transform_point = Geom::Transformation.new @connector_point,@connector_vector
						@draw_flange_pts = @flange_dots.collect{|dots|;dots.collect{|pt|;pt.transform(@transform_point)}} if @flange_dots!=nil #Для рисования сетки заглушки
						@draw_flange_bolts=@flange_bolts.collect{|bolt|;bolt.collect{|dots|;dots.collect{|pt|;pt.transform(@transform_point)}}} if @flange_bolts!=nil #Отверстия для ботов
						@connector_point = (Geom::Point3d.new).transform(@transform_point)
					end
				else
					@connector_vector = nil
					@connector_point = nil
					@drawconnector = false
				end
			end
		end
		def onLButtonDown(flags, x, y, view)             #Нажатие на левую клавишу мыши
			if  @state == STATE_SELECT_FIRST_POINT
				@ip1.pick view, x, y
				if @draw_flange_pts.length>0 #если есть отображение сетки, можно переходить к следующему этапу
					if( @ip1.valid? )
						Sketchup.active_model.select_tool nil
						@param[:view]=view
						cp_create_flange_geometry
					end
					if @drawconnector
						@ip1 = Sketchup::InputPoint.new(@connector_point)
					end
				end
			end
			view.lock_inference
		end
		def generate_flange_dots                   #Создание опорных точек для построения фланца
			d1 = @param[:D1].to_f
			d2 = @param[:D2].to_f
			d3 = @param[:D3].to_f
			d4 = @param[:D4].to_f
			d5 = @param[:D5].to_f.mm/2 #Расположение болтового отверстия - при содействии Nemesis
			h1 = @param[:h1].to_f.mm
			h2 = @param[:h2].to_f.mm
			h3 = @param[:h3].to_f.mm
			h1_to_h2=h1+h2
			h1_to_h3=h1+h2+h3
			n  = @param[:n_отв].to_f   #Кол-во отверстий под болты
			d  = @param[:d_отв].to_f   #диаметр отверстий под болты
			segm = @param[:Cегментов].to_i         #Кол-во сегментов
			segm = $cp_segments if segm<$cp_segments
			delta_angle = 360/segm
			point = [0,0,0]
			vector = [0,0,1]                       #Вектор вокруг которого рисуется фланец
			point_h1 = [0,0,h1]
			point_h2 = [0,0,h1_to_h2]
			point_h3 = [0,0,h1_to_h3]
			trans_h1 = Geom::Transformation.new point_h1
			trans_h2 = Geom::Transformation.new point_h2
			trans_h3 = Geom::Transformation.new point_h3
			circle1 = generate_arc(d1/2,0,360,delta_angle)
			circle2 = generate_arc(d2/2,0,360,delta_angle)
			circle3 = generate_arc(d3/2,0,360,delta_angle)
			circle4 = generate_arc(d4/2,0,360,delta_angle)
			@flange_dots = []
			@flange_dots << circle1
			@flange_dots << circle2.collect {|pt|;pt.transform(trans_h1)}
			@flange_dots << circle3.collect {|pt|;pt.transform(trans_h1)}
			@flange_dots << circle3.collect {|pt|;pt.transform(trans_h2)}
			@flange_dots << circle4.collect {|pt|;pt.transform(trans_h2)}
			@flange_dots << circle4.collect {|pt|;pt.transform(trans_h3)}
			#Создание массива отверстий для болтов
			circle = generate_arc(d/2,0,360,delta_angle)
			xpos = d5 #d2.mm+d3.mm)/4 #Расположение болтового отверстия - при содействии Nemesis
			point_pos1 = [xpos,0,h1]
			point_pos2 = [xpos,0,h1_to_h2]
			trans_move1 = Geom::Transformation.new point_pos1
			trans_move2 = Geom::Transformation.new point_pos2
			circle1 = circle.collect {|pt|;pt.transform(trans_move1)}
			circle2 = circle.collect {|pt|;pt.transform(trans_move2)}
			delta_angle_poscircle = 360/(n)
			@flange_bolts = []
			alfa1 = (360/n)*0.5
			alfa2 = (360/n)*0.5
			alfa1.step((360+alfa2-delta_angle_poscircle),delta_angle_poscircle){|angle|
				rotation = Geom::Transformation.rotation point, vector, angle.degrees
				@flange_bolts << [(circle1.collect {|pt|;pt.transform(rotation)}),(circle2.collect {|pt|;pt.transform(rotation)})]
			}
			if @flange_component #Если фланец присоединяется к фланцу - то переворачиваем все на 180 градусов (определяется в where_connector
				point = [0,0,h1_to_h3/2] #Центр фланца
				vecFla = point.vector_to(point_h3) #вектор от центра к концу фланца
				axes = vecFla.axes #Система координат относительно центра фланца
				rotation = Geom::Transformation.rotation point, axes[1], 180.degrees #Поворот на 180 град относительно y ветора локальной системы координат
				@flange_dots = @flange_dots.collect{|circle|;circle.collect{|pt|;pt.transform(rotation)}if circle!=nil}
				@flange_bolts = @flange_bolts.collect{|bolt|;bolt.collect{|storona|;storona.collect{|pt|;pt.transform(rotation)}}}
			end
			@flange_dots.compact
		end
		def draw_flange_dots(view)                          #Отрисовка сетки будущего фланца
			#Отрисовка фланца
			draw_array_circlepts(@draw_flange_pts,view)
			#Отрисовка отверстий под болты
			for i in 0..(@flange_bolts.length-1)
				draw_array_circlepts(@draw_flange_bolts[i],view)
			end
		end
		def draw(view)
			draw_flange_dots(view)
			view.line_stipple = ""
			view.draw_points  @connector_point, 10, 1, "red" if (@connector_point!=nil)&&(@connector_vector!=nil)
		end
		def cp_flange_massa                          #расчет массы фланца
			d1 = @param[:D1].to_f;d2 = @param[:D2].to_f;d3 = @param[:D3].to_f;d4 = @param[:D4].to_f
			r1 = d1/2; r2 = d2/2; r3 = d3/2; r4 = d4/2
			h1 = @param[:h1].to_f;h2 = @param[:h2].to_f;h3 = @param[:h3].to_f
			md = @param[:d_отв].to_f;nd =@param[:n_отв].to_f
			rd = md/2
			du = @param[:Ду].to_f;ru = du/2
			vol1 = (1/3)*Math::PI*h1*(r1*r1+r1*r2+r2*r2) #расчитывается по формуле объема усеченного конуса (присоединение к трубе)
			vol2 = Math::PI*r3*r3*h2 #Расчитывается по формуле цилиндра (сам фланец в котором прорезаны отверстия под болты)
			vol3 = Math::PI*r4*r4*h3 #Расчитывается по формуле цилиндра (присоединение ответного фланца)
			vol4 = Math::PI*rd*rd*h2*nd #Расчитывается по формуле цилиндра - сумма объемов отверстий под болты
			vol5 = Math::PI*ru*ru*(h1+h2+h3) #Расчитывается по формуле цилиндра - отверстие под условный проход трубы
			volume = vol1+vol2+vol3-vol4-vol5
			massa = ($cp_elbowPlotnost*volume/10000).to_i.to_f/100
			massa
		end
		def cp_calculate_flange_area #----- #добавлено в 1.4.1(2018)
			d    = @param[:d_отв].to_f/1000
         n    = @param[:n_отв].to_f
         d1   = @param[:D1].to_f/1000
         d2   = @param[:D2].to_f/1000
         d3   = @param[:D3].to_f/1000
         d4   = @param[:D4].to_f/1000
         h1   = @param[:h1].to_f/1000
         h2   = @param[:h2].to_f/1000
         h3   = @param[:h3].to_f/1000
         s1   = Math::PI*d4*h3
         s2   = Math::PI*(d3/2)**2-Math::PI*(d4/2)**2-n*Math::PI*(d/2)**2
         s3   = Math::PI*d3*h2
         s4   = Math::PI*(d3/2)**2-Math::PI*(d2/2)**2-n*Math::PI*(d/2)**2
         s5   = Math::PI*Math.sqrt(h1**2 + ((d2/2-d1/2).abs)**2)*(d2/2+d1/2)
         s = s1+s2+s3+s4+s5
         s = Sketchup::CoolPipe::roundf(s,6)#.round(6)
         s
		end
		def cp_createflangeattributes(param)              #создает список атрибутов для Фланца
			attributes={}
			if param!=nil
			attributes={:Тип         => "Фланец",                        #Тип компонента: Фланец
						:Имя            => param[:Имя],                     #Наименование для спецификации
						:ЕдИзм          => $coolpipe_langDriver["шт"], 		 #Единица измерения для спецификации
						:ГОСТ           => param[:ГОСТ],                    #Нормативный документ (из базы)
						:Dнар           => param[:Dнар],
						:стенка         => param[:стенка],
						:масса          => cp_flange_massa.to_s,
						:Материал       => param[:Материал],                #Материал трубопровода (собственный цвет из настроек слоев)-если нет то 0
						:typemodel      => "cyl",                           #Тип отрисованного объекта (cyl = цилиндрический, flange = с внутренней геометрией)
						:Площадь			 => cp_calculate_flange_area.to_s,   #Расчет площади фланца для окраски -- #добавлено в 1.4.1(2018) #-- #добавлено в 1.4.1(2018)
						:Стандартный_элемент =>"true"				             #элемент является стандартным #-добавка версии 1.4.1(2018)
						}
			end
			attributes
		end #cp_createelbowattributes(param)
		def get_bolts_mesh(circlepts_array)
			mesh = Geom::PolygonMesh.new
			pre_pts = nil
			circlepts_array.each {|pts| #pts - точки опорных окружностей сегментов
				if pre_pts!=nil
					if pts!=pre_pts
						for i in 0..(pts.length-2)
							point1 = pts[i]
							point2 = pts[i+1]
							point3 = pre_pts[i+1]
							point4 = pre_pts[i]
							mesh.add_polygon point1, point2, point3, point4
						end
					end
					pre_pts = pts
				else
					pre_pts = pts
				end
			}
			mesh
		end
		def get_flange_mesh(circle_array)
			mesh = Geom::PolygonMesh.new
			0.step(5,2){|i|
				for j in 0..(circle_array[i].length-2)
					point1 = circle_array[i][j]
					point2 = circle_array[i+1][j]
					point3 = circle_array[i+1][j+1]
					point4 = circle_array[i][j+1]
					mesh.add_polygon point1, point2, point3, point4
				end
			}
			mesh
		end
		def cp_create_flange_geometry
			if @draw_flange_pts.length>0
				view = @param[:view]
				prevlayer1 = setactivLayer(@layer) if @layer!=nil # Устанавливаем активный слой если задан в параметрах
				model = view.model
				model.start_operation "Создание объекта CoolPipe::CircleFlange"
				entities = model.active_entities
				groupglob=entities.add_group
				entities = groupglob.entities
				group=entities.add_group
				entities = group.entities
				component=groupglob.to_component
				attributes = cp_createflangeattributes(@param)
				name =attributes[:Имя]
				component.name = "Flange: #{name}"
				component.definition.name="Flange: #{name}"
				connector_pts = []
				flange_mesh = get_flange_mesh(@draw_flange_pts) #Создание полигонов Фланца
				bolt_mesh = []
				bolt_countpoligon = 0
				@draw_flange_bolts.each{|bolt_circlearray|  #Создание полигонов отверстий под болты
					mesh = get_bolts_mesh(bolt_circlearray)
					bolt_mesh << mesh
					bolt_countpoligon = bolt_countpoligon + mesh.count_polygons
				}
				puts "#{$coolpipe_langDriver["Количество полигонов составляет"]} #{flange_mesh.count_polygons+bolt_countpoligon} #{$coolpipe_langDriver["шт"]}"
				entities.add_faces_from_mesh flange_mesh
				bolt_mesh.each{|mesh|;entities.add_faces_from_mesh mesh}
				entities.each{|face|;face.reverse! if face.class==Sketchup::Face}
				for i in 0..5
					face1 = entities.add_face @draw_flange_pts[i] if i==0
					face2 = entities.add_face @draw_flange_pts[i] if (i>0)and(i<5)
					face3 = entities.add_face @draw_flange_pts[i] if i==5
				end
				face2.hidden = true if face2!=nil
				@draw_flange_bolts.each{|bolt_circlearray|
					boltface1 = entities.add_face bolt_circlearray[0]
					boltface2 = entities.add_face bolt_circlearray[1]
					boltface1.hidden=true;boltface2.hidden=true #Здесь вырезаем отверстия под болты
				}
				point1=entities.add_cpoint(Geom::BoundingBox.new.add(@draw_flange_pts[0]).center)
				point2=entities.add_cpoint(Geom::BoundingBox.new.add(@draw_flange_pts[@draw_flange_pts.length-1]).center)
				set_connector_point(point1,face1.normal.reverse!)
				set_connector_point(point2,face3.normal.reverse!)
				pts = [point1.position,point2.position]
				line = entities.add_line pts #осевая линия
				if $cp_vnGeom #нужно вырезать отверстие Dнар если true
					#####################
					du = (@param[:D1].to_f*0.95).mm
					pt1 = Geom::BoundingBox.new.add(@draw_flange_pts[0]).center
					pt2 = Geom::BoundingBox.new.add(@draw_flange_pts[@draw_flange_pts.length-1]).center
					vector = pt1.vector_to pt2
					pts1 = []
					edges1 = entities.add_circle pt1,vector,(du/2),$cp_segments
					edges1.each{|edge|;pts1<<edge.start.position;}
					face1 = entities.add_face pts1
					face1.pushpull(vector.length, false) if face1!=nil
					#####################
				end
				entities.each{|face|;face.reverse! if face.class==Sketchup::Face}
				behavior = component.definition.behavior #Для ограничения вариантов масштабирования объекта
				mask = (1<<0)+(1<<1)+(1<<2)+(1<<3)+(1<<4)+(1<<5)+(1<<6) #запрет масштабирования
				behavior.no_scale_mask = mask #Применяем маску
				cp_setattributes(attributes,component)
				setactivLayer(prevlayer1) if prevlayer1!=nil #Восстанавливаем исходный слой
				component.material = @material if @material!=nil
				model.commit_operation
				puts "#{$coolpipe_langDriver["Начерчен: "]}#{name}"
			end
			component
		end
	end #class ToolDrawFlange < ToolDrawElement
	########################################################################################
	# Редактирование элементов
	########################################################################################
	class ToolEditPipe    < ToolEditElement  #Инструмент редктирования трубопровода
		def initialize(name,component,selection)
			super(name,component,selection)
			@passive_color   = "Bisque"
			@active_color    = "LightGreen"
		end
		def reset(view)
			super(view)
			getparams_frompipe
		end
		def getparams_frompipe                  #Получает основные характеристики текущего трубопровода
			@layer = @component_pipe.layer.name #получаем слой трубы
			@materialcolor = @component_pipe.material #получаем материал используемый для трубы
			@attributes = Sketchup::CoolPipe::cp_getattributes(@component_pipe)
			connectors = Sketchup::CoolPipe::cp_get_connectors_arr(@component_pipe)
			@face_begin = connectors[0] #Первый коннектор отвода
			@face_end   = connectors[1] #Второй коннектор отвода
			#@xaxes,@yaxes,@zaxes = cp_get_axes_connector(@component_pipe,@face_end)
			#tr1 = @component_pipe.definition.entities[0].transformation #обратная трансформация группы для получения абсолютных координат
			tr2 = @component_pipe.transformation #обратная трансформация компонента для получения абсолютных координат
			if @pt_begin==nil
				@pt_begin = @face_begin.bounds.center
				#@pt_begin = @pt_begin.transform! tr1
				@pt_begin = @pt_begin.transform! tr2
			end
			if @pt_end==nil
				@pt_end = @face_end.bounds.center
				#@pt_end = @pt_end.transform! tr1
				@pt_end = @pt_end.transform! tr2
			end
			@vector_pipe= @pt_end - @pt_begin if @vector_pipe==nil
			@length = cp_get_length_tube(@component_pipe,@attributes) if @length==nil
			@pt_center = @pt_begin.offset @vector_pipe,(@length*1000/2).mm if @pt_center==nil
		end
		def cp_get_length_tube(tube,attributes) #Метод определяет длину трубопровода
			length = 0
			connectors = Sketchup::CoolPipe::cp_get_connectors_arr(tube)
			if (connectors.length==2) && (attributes[:Тип]=="Труба")
				#tr1 = tube.definition.entities[0].transformation #обратная трансформация группы для получения абсолютных координат
				tr2 = tube.transformation                        #обратная трансформация компонента для получения абсолютных координат
				pt1 = connectors[0].bounds.center                #получение абсолютной точки начала трубопровода
				#pt1 = pt1.transform! tr1
				pt1 = pt1.transform! tr2
				pt2 = connectors[1].bounds.center                #получение абсолютной точки начала трубопровода
				#pt2 = pt2.transform! tr1
				pt2 = pt2.transform! tr2
				vec = pt1 - pt2
			end
			length = ((vec.length.to_m*100).round.to_f)/100
			length
		end
		def on_menu_click(command,view)
			#begin_z = @pt_begin.z
			#end_z = @pt_end.z
			js_script = ""
			direction=0 #1=begin 2=center 3=end 0=cancel
			case command
				when "Редактировать"
					if @cp_edit_pipe_enable ==false
						@cp_edit_pipe_enable =true
					else
						@cp_edit_pipe_enable =false
				   end
				when "Уклон_>"
					if @uklon_leftmenu
						@uklon_leftmenu=false
					else @uklon_leftmenu=true
					end
				when "Уклон_<"
					if @uklon_rightmenu
						@uklon_rightmenu=false
					else @uklon_rightmenu=true
					end
				when "Поменять_направление"  #
					tr = Geom::Transformation.rotation @pt_center, @xaxes, 180.degrees
					@component_pipe.transform! tr #вращение трубы на 180 градусов согласно направляющей
					puts $coolpipe_langDriver["Измененно направление (начало/конец) трубопровода"]
				when ">"  # изменить направление уклона
					@attributes[:Точка_начала] = Geom::Point3d.new @pt_begin.x,@pt_begin.y,@pt_end.z
					@attributes[:Точка_конца]  = Geom::Point3d.new @pt_end.x,@pt_end.y,@pt_begin.z
					puts $coolpipe_langDriver["Измененно направление уклона трубопровода"]
				when "<"  # изменить направление уклона
					@attributes[:Точка_начала] = Geom::Point3d.new @pt_begin.x,@pt_begin.y,@pt_end.z
					@attributes[:Точка_конца]  = Geom::Point3d.new @pt_end.x,@pt_end.y,@pt_begin.z
					puts $coolpipe_langDriver["Измененно направление уклона трубопровода"]
					#-------------
				when ">0.015"
					@attributes[:Точка_начала] = Geom::Point3d.new @pt_begin.x,@pt_begin.y,@pt_begin.z
					@attributes[:Точка_конца]  = Geom::Point3d.new @pt_end.x,@pt_end.y,@pt_begin.z-0.015*@vector_pipe.length
					puts $coolpipe_langDriver["Выбран уклон трубопровода"]+" >0.0015"
				when ">0.02"
					@attributes[:Точка_начала] = Geom::Point3d.new @pt_begin.x,@pt_begin.y,@pt_begin.z
					@attributes[:Точка_конца]  = Geom::Point3d.new @pt_end.x,@pt_end.y,@pt_begin.z-0.02*@vector_pipe.length
					puts $coolpipe_langDriver["Выбран уклон трубопровода"]+" >0.002"
				when ">0.025"
					@attributes[:Точка_начала] = Geom::Point3d.new @pt_begin.x,@pt_begin.y,@pt_begin.z
					@attributes[:Точка_конца]  = Geom::Point3d.new @pt_end.x,@pt_end.y,@pt_begin.z-0.025*@vector_pipe.length
					puts $coolpipe_langDriver["Выбран уклон трубопровода"]+" >0.0025"
				when ">0.03"
					@attributes[:Точка_начала] = Geom::Point3d.new @pt_begin.x,@pt_begin.y,@pt_begin.z
					@attributes[:Точка_конца]  = Geom::Point3d.new @pt_end.x,@pt_end.y,@pt_begin.z-0.03*@vector_pipe.length
					puts $coolpipe_langDriver["Выбран уклон трубопровода"]+" >0.003"
				when ">0.035"
					@attributes[:Точка_начала] = Geom::Point3d.new @pt_begin.x,@pt_begin.y,@pt_begin.z
					@attributes[:Точка_конца]  = Geom::Point3d.new @pt_end.x,@pt_end.y,@pt_begin.z-0.035*@vector_pipe.length
					puts $coolpipe_langDriver["Выбран уклон трубопровода"]+" >0.0035"
					#-------------
				when "<0.015"
					@attributes[:Точка_начала] = Geom::Point3d.new @pt_begin.x,@pt_begin.y,@pt_end.z-0.015*@vector_pipe.length
					@attributes[:Точка_конца]  = Geom::Point3d.new @pt_end.x,@pt_end.y,@pt_end.z
					puts $coolpipe_langDriver["Выбран уклон трубопровода"]+" <0.0015"
				when "<0.02"
					@attributes[:Точка_начала] = Geom::Point3d.new @pt_begin.x,@pt_begin.y,@pt_end.z-0.02*@vector_pipe.length
					@attributes[:Точка_конца]  = Geom::Point3d.new @pt_end.x,@pt_end.y,@pt_end.z
					puts $coolpipe_langDriver["Выбран уклон трубопровода"]+" <0.002"
				when "<0.025"
					@attributes[:Точка_начала] = Geom::Point3d.new @pt_begin.x,@pt_begin.y,@pt_end.z-0.025*@vector_pipe.length
					@attributes[:Точка_конца]  = Geom::Point3d.new @pt_end.x,@pt_end.y,@pt_end.z
					puts $coolpipe_langDriver["Выбран уклон трубопровода"]+" <0.0025"
				when "<0.03"
					@attributes[:Точка_начала] = Geom::Point3d.new @pt_begin.x,@pt_begin.y,@pt_end.z-0.03*@vector_pipe.length
					@attributes[:Точка_конца]  = Geom::Point3d.new @pt_end.x,@pt_end.y,@pt_end.z
					puts $coolpipe_langDriver["Выбран уклон трубопровода"]+" <0.003"
				when "<0.035"
					@attributes[:Точка_начала] = Geom::Point3d.new @pt_begin.x,@pt_begin.y,@pt_end.z-0.035*@vector_pipe.length
					@attributes[:Точка_конца]  = Geom::Point3d.new @pt_end.x,@pt_end.y,@pt_end.z
					puts $coolpipe_langDriver["Выбран уклон трубопровода"]+" <0.0035"
					#-------------
				when "изм.r"  #
					js_script = "setz(\"#{((@pt_begin.z.to_f*25.4*100).round.to_f/100).to_s}\");"
					dialog_change_z(js_script,"1",view)
				when "изм.c"  #
					js_script = "setz(\"#{((@pt_center.z.to_f*25.4*100).round.to_f/100).to_s}\");"
					dialog_change_z(js_script,"2",view)
				when "изм.l"  #
					js_script = "setz(\"#{((@pt_end.z.to_f*25.4*100).round.to_f/100).to_s}\");"
					dialog_change_z(js_script,"3",view)
				when "Изменить_диаметр"
					$coolpipe_dialogs.cp_selectpipe_dialog(change_diametr = true)
			end #case @active_command
		end
		def draw(view)
			add_menu_item(view,5,5,100,20,$coolpipe_langDriver["Редактировать"],"Редактировать")
			if @cp_edit_pipe_enable
				draw_visual_pipe(view)
				print_connectors_coords(view)
				put_a_to_b(view)#обозначаем начало и конец трубопровода
				put_angle(view) #печатаем уклон трубопровода
				point1 = Geom::Point3d.new 110,5,0
				status1 = view.draw_text point1,$coolpipe_langDriver["Выделено:"]+@name
				add_menu_item(view,50,80,65,20,$coolpipe_langDriver["изменить"],"изм.r")
				add_menu_item(view,255,50,65,20,$coolpipe_langDriver["изменить"],"изм.c")
				add_menu_item(view,385,80,65,20,$coolpipe_langDriver["изменить"],"изм.l")
				#add_menu_item(view,170,170,155,20,"Поменять направление","Поменять_направление")
				#add_menu_item(view,170,195,155,20,"Задать уклон","Задать_уклон")
				add_menu_item(view,170,170,155,20,$coolpipe_langDriver["Изменить диаметр"],"Изменить_диаметр")
				if (@pt_begin!=nil) && (@pt_end!=nil)
					if @pt_begin.z>@pt_end.z
						add_menu_item(view,180,140,20,17,">",">")
					end
					if @pt_begin.z<@pt_end.z
						add_menu_item(view,180,140,20,17,"<","<")
					end
				end
				add_menu_item(view,50,105,65,20,$coolpipe_langDriver["Уклон"]+" >","Уклон_>")
				add_menu_item(view,385,105,65,20,$coolpipe_langDriver["Уклон"]+" <","Уклон_<")
				if @uklon_leftmenu
					add_menu_item(view,50,130,65,20,">0.015",">0.015")
					add_menu_item(view,50,155,65,20,">0.02",">0.02")
					add_menu_item(view,50,180,65,20,">0.025",">0.025")
					add_menu_item(view,50,205,65,20,">0.03",">0.03")
					add_menu_item(view,50,230,65,20,">0.035",">0.035")
				end
				if @uklon_rightmenu
					add_menu_item(view,385,130,65,20,"<0.015","<0.015")
					add_menu_item(view,385,155,65,20,"<0.02","<0.02")
					add_menu_item(view,385,180,65,20,"<0.025","<0.025")
					add_menu_item(view,385,205,65,20,"<0.03","<0.03")
					add_menu_item(view,385,230,65,20,"<0.035","<0.035")
				end
			end
		end
		def print_connectors_coords(view)
			a = @pt_begin.to_s
			b = @pt_end.to_s
			point1 = Geom::Point3d.new 10,200,0
			point2 = Geom::Point3d.new 10,220,0
			status1 = view.draw_text point1, $coolpipe_langDriver["Координаты синего коннектора"]+": "+a
			status2 = view.draw_text point2, $coolpipe_langDriver["Координаты красного коннектора"]+": "+b
		end
		def put_a_to_b(view) #начало и конец трубопровода
			screen_begin = view.screen_coords(@pt_begin)
			screen_end   = view.screen_coords(@pt_end)
			view.line_width = 3
			view.drawing_color = "Blue"
			point11 = screen_begin
			point12 = Geom::Point3d.new screen_begin.x,screen_begin.y-25,0
			point13 = Geom::Point3d.new screen_begin.x-10,screen_begin.y-10,0
			point14 = Geom::Point3d.new screen_begin.x+10,screen_begin.y-10,0
			view.draw2d GL_LINES, point11, point12
			view.draw2d GL_LINES, point11, point13
			view.draw2d GL_LINES, point11, point14
			point31 = Geom::Point3d.new 150,75,0
			point32 = Geom::Point3d.new 150,50,0
			point33 = Geom::Point3d.new 140,65,0
			point34 = Geom::Point3d.new 160,65,0
			view.draw2d GL_LINES, point31, point32
			view.draw2d GL_LINES, point31, point33
			view.draw2d GL_LINES, point31, point34
			view.drawing_color = "Red"
			point21 = screen_end
			point22 = Geom::Point3d.new screen_end.x,screen_end.y-25,0
			point23 = Geom::Point3d.new screen_end.x-10,screen_end.y-10,0
			point24 = Geom::Point3d.new screen_end.x+10,screen_end.y-10,0
			view.draw2d GL_LINES, point21, point22
			view.draw2d GL_LINES, point21, point23
			view.draw2d GL_LINES, point21, point24
			point41 = Geom::Point3d.new 350,75,0
			point42 = Geom::Point3d.new 350,50,0
			point43 = Geom::Point3d.new 340,65,0
			point44 = Geom::Point3d.new 360,65,0
			view.draw2d GL_LINES, point41, point42
			view.draw2d GL_LINES, point41, point43
			view.draw2d GL_LINES, point41, point44
		end
		def draw_visual_pipe(view)
			getparams_frompipe
			view.drawing_color = "blue"
			view.line_width = 3
			point11 = Geom::Point3d.new 150,80,0
			point12 = Geom::Point3d.new 350,80,0
			point13 = Geom::Point3d.new 350,110,0
			point14 = Geom::Point3d.new 150,110,0
			point15 = Geom::Point3d.new 150,95,0
			point16 = Geom::Point3d.new 350,95,0
			status2 = view.draw2d GL_LINE_STRIP, point11, point12, point13, point14,point11
			view.drawing_color = "red"
			view.line_width = 1
			status2 = view.draw2d GL_LINES, point15, point16
			if @pt_begin!=nil
			put_otmetka(view,130,95,@pt_begin.z,0)  if @pt_begin!=nil  #с лева
			put_otmetka(view,370,95,@pt_end.z,1)    if @pt_end!=nil    #с права
			put_otmetka(view,250,95,@pt_center.z,0) if @pt_center!=nil #центр
			end
			put_lengthpipe(view)
		end
		def put_otmetka(view,x,y,otmetka_z,pos)
			point11 = Geom::Point3d.new x,y,0
			point12 = Geom::Point3d.new x-7,y-10,0
			point13 = Geom::Point3d.new x+7,y-10,0
			point17 = Geom::Point3d.new x-12,y,0
			point18 = Geom::Point3d.new x+12,y,0
			view.drawing_color = "black"
			view.line_width = 2
			if pos==0 #левая сторона
				point14 = Geom::Point3d.new x,y-25,0
				point15 = Geom::Point3d.new x-80,y-25,0
				point16 = Geom::Point3d.new x-70,y-42,0
			end
			if pos==1 #правая сторона
				point14 = Geom::Point3d.new x,y-25,0
				point15 = Geom::Point3d.new x+80,y-25,0
				point16 = Geom::Point3d.new x+10,y-42,0
			end
			status2 = view.draw2d GL_LINES, point11, point12
			status2 = view.draw2d GL_LINES, point11, point13
			status2 = view.draw2d GL_LINES, point11, point14
			status2 = view.draw2d GL_LINES, point14, point15
			status2 = view.draw2d GL_LINES, point17, point18
			if otmetka_z>0
				s="+"
			else
				s=""
			end
			z = (((otmetka_z.to_mm*100).round.to_f)/100)
			status2 = view.draw_text point16, s+z.to_s
		end
		def put_lengthpipe(view)
			view.drawing_color = "black"
			view.line_width = 2
			point11 = Geom::Point3d.new 150,115,0
			point12 = Geom::Point3d.new 150,150,0
			status2 = view.draw2d GL_LINES, point11, point12
			point13 = Geom::Point3d.new 350,115,0
			point14 = Geom::Point3d.new 350,150,0
			status2 = view.draw2d GL_LINES, point13, point14
			point15 = Geom::Point3d.new 160,125,0
			point16 = Geom::Point3d.new 140,145,0
			status2 = view.draw2d GL_LINES, point15, point16
			point17 = Geom::Point3d.new 360,125,0
			point18 = Geom::Point3d.new 340,145,0
			status2 = view.draw2d GL_LINES, point17, point18
			point19 = Geom::Point3d.new 135,135,0
			point10 = Geom::Point3d.new 365,135,0
			status2 = view.draw2d GL_LINES, point19, point10
			text_point = Geom::Point3d.new 200,118,0
			status2 = view.draw_text text_point, "L = "+@vector_pipe.length.to_s
		end
		def put_angle(view)
			vec1 = @pt_begin-@pt_end
			pt1  = Geom::Point3d.new @pt_end.x,@pt_end.y,@pt_begin.z
			vec2 = @pt_begin-pt1
			@angle = vec1.angle_between vec2
			@angle = @angle*180/Math::PI
			text_point = Geom::Point3d.new 210,140,0
			status  = view.draw_text text_point, $coolpipe_langDriver["Уклон"]+" = "+(((@angle*100).round.to_f)/100).to_s+"°"
		end
		def redrawpipe(view)
			if (@attributes[:Точка_начала]!=nil) && (@attributes[:Точка_конца]!=nil)
				model = view.model
				model.start_operation "Редактирование объекта CoolPipe::CirclePipe"
					@attributes[:view]=view
					@attributes[:Сегментов] = $cp_segments
					layer = @component_pipe.layer if @component_pipe!=nil
					@component_pipe.erase! if @component_pipe!=nil
					@component_pipe=nil
					pt1 = @attributes[:Точка_начала]
					pt2 = @attributes[:Точка_конца]
					drawpipe = ToolDrawPipe.new
					@component_pipe=drawpipe.cp_create_pipe_geometry(@attributes,pt1,pt2,view) #Создание геометрии трубы
					@component_pipe.layer = layer if layer!=nil
					definitions = model.definitions
					definitions.purge_unused
				model.commit_operation
				emulselection(@component_pipe) if @component_pipe!=nil
			end
		end
		def change_diam(param)
			param[:view]=@view
			param[:Точка_начала]=@pt_begin
			param[:Точка_конца]=@pt_end
			#param.each_pair{|key, value| puts "key="+key.to_s+" value="+value.to_s }
			@attributes = param.clone
			redrawpipe(param[:view])
		end
		def dialog_change_z(js_script,direction,view)
			dlg=UI::WebDialog.new($coolpipe_langDriver["Изменить отметку Z"], false, $coolpipe_langDriver["Изменить отметку Z"],150,250,0,0,true) #width,height,left,top
			dlg.set_file(File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/change_z.html")))
			color = dlg.get_default_dialog_color
			dlg.set_background_color(color)
			dlg.add_action_callback("ValueChanged") {|d,p|
			arr=p.split("|") # парсинг полученых параметров
			case arr[0]
				when "load_succesfull"
					dlg.execute_script("document.getElementById('text_ok').value=\"#{$coolpipe_langDriver["Принять"]}\"")
					dlg.execute_script("document.getElementById('text_cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
					dlg.execute_script(js_script)
				when "1" #Принять
					command = "1"
					begin
						newz = arr[1].to_f
					rescue
						puts $coolpipe_langDriver["Не могу конвертировать введенное значение"]
						command="0"
					end
					if command=="1"
						case direction
							when "1" #1=begin
								new_pt_begin = Geom::Point3d.new @pt_begin.x,@pt_begin.y,newz.to_f.mm
								@attributes[:Точка_начала] = new_pt_begin
								@attributes[:Точка_конца]  = @pt_end
								puts $coolpipe_langDriver["Изменена синия отметка"]
							when "2" #2=center
								delta = newz.to_f.mm - @pt_center.z
								new_pt_begin = Geom::Point3d.new @pt_begin.x,@pt_begin.y,@pt_begin.z+delta
								new_pt_end = Geom::Point3d.new @pt_end.x,@pt_end.y,@pt_end.z+delta
								@attributes[:Точка_начала] = new_pt_begin
								@attributes[:Точка_конца]  = new_pt_end
								puts $coolpipe_langDriver["Изменена средняя отметка"]
							when "3" #3=end
								new_pt_end = Geom::Point3d.new @pt_end.x,@pt_end.y,newz.to_f.mm
								@attributes[:Точка_начала] = @pt_begin
								@attributes[:Точка_конца]  = new_pt_end
								puts $coolpipe_langDriver["Изменена красная отметка"]
						end
						#redrawpipe(view) #Перерисовка трубы с новыми параметрами
					end
					dlg.close if @component_pipe!=nil
				when "0" #Отмена
					dlg.close
			end
			}
			dlg.max_height = 130
			dlg.max_width  = 280
			dlg.min_height = 130
			dlg.min_width  = 280
			dlg.show_modal
		end
	end #class ToolEditPipe < ToolEditElement
	######
	class ToolEditElbow   < ToolEditElement  #Инструмент редктирования отвода
		#ВРЕМЕННО ОТМЕНЕН
	end #class ToolEditElbow < ToolEditElement
	######
	class ToolEditReducer < ToolEditElement  #Инструмент редктирования переходника
		def initialize(name,component,selection)
			super(name,component,selection)
			@passive_color   = "Bisque"
			@active_color    = "LightGreen"
			getparams_fromcomponent(@component_pipe)
		end
		def reset(view)
			if( view )
				view.tooltip = nil
				view.invalidate if @drawn
			end
			@drawn = false
			@dragging = false
			@active_command = ""
			@screen_menu    = []
			#@pt_begin = nil
			@pt_center= nil
			#@pt_end   = nil
		end
		def draw(view)
			add_menu_item(view,5,5,100,20,$coolpipe_langDriver["Редактировать"],"Редактировать")
			if @cp_edit_pipe_enable
				point1 = Geom::Point3d.new 110,5,0
				status1 = view.draw_text point1, $coolpipe_langDriver["Выделено:"]+@name
				add_menu_item(view,5,35,140,20,$coolpipe_langDriver["Изменить диаметры"],"Изменить диаметры")
				add_menu_item(view,5,65,140,20,$coolpipe_langDriver["Повернуть на 180°"],"Повернуть на 180°")
				draw_visual_reducer_info(view)
			end
			invalidated_view = view.invalidate
		end
		def getparams_fromcomponent(component)
			trans = component.transformation
			@attributes = Sketchup::CoolPipe::cp_getattributes(component)
			@connectors = Sketchup::CoolPipe::cp_get_connectors_arr(component)
			@center_conectors = Sketchup::CoolPipe::cp_get_real_center_connectors(component)
			@pt_begin = @center_conectors[0]
			@pt_end = @center_conectors[1]
			#puts "@pt_begin=#{@pt_begin}"
			#puts "@pt_end=#{@pt_end}"
			axes1 = (@connectors[0].position.transform!(trans)-@connectors[1].position.transform!(trans)).normalize!.axes
			@xaxes1 = axes1[0];
			@yaxes1 = axes1[1];
			@zaxes1 = axes1[2];
			axes2 = (@connectors[1].position.transform!(trans)-@connectors[0].position.transform!(trans)).normalize!.axes
			@xaxes2 = axes2[0];
			@yaxes2 = axes2[1];
			@zaxes2 = axes2[2];
		end
		def draw_visual_reducer_info(view)
			#---Рисуем переход
			if (@pt_begin!=nil)and(@pt_end!=nil)
				pts=[]
				pts << (Geom::Point3d.new 110,100,0)
				pts << (Geom::Point3d.new 120,100,0)
				pts << (Geom::Point3d.new 270,140,0)
				pts << (Geom::Point3d.new 280,140,0)
				pts << (Geom::Point3d.new 280,220,0)
				pts << (Geom::Point3d.new 270,220,0)
				pts << (Geom::Point3d.new 120,260,0)
				pts << (Geom::Point3d.new 110,260,0)
				pts << (Geom::Point3d.new 110,100,0)
				view.drawing_color = "blue"
				view.line_width = 3
				view.draw2d GL_LINE_STRIP,pts
				view.drawing_color = "red"
				view.line_width = 1
				pt1 = Geom::Point3d.new 110,180,0
				pt2 = Geom::Point3d.new 280,180,0
				view.draw2d GL_LINES, pt1, pt2
				#---Рисуем отметки
				put_otmetka(view,pt1.x-10,pt1.y,@pt_begin.z,0,"blue")
				put_otmetka(view,pt2.x+10,pt2.y,@pt_end.z,1,"red")
				#---Отмечаем коннекторы
				screen_begin = view.screen_coords(@pt_begin)
				screen_end   = view.screen_coords(@pt_end)
				view.line_width = 3
				view.drawing_color = "Blue"
				point11 = screen_begin
				point12 = Geom::Point3d.new screen_begin.x,screen_begin.y-25,0
				point13 = Geom::Point3d.new screen_begin.x-10,screen_begin.y-10,0
				point14 = Geom::Point3d.new screen_begin.x+10,screen_begin.y-10,0
				view.draw2d GL_LINES, point11, point12
				view.draw2d GL_LINES, point11, point13
				view.draw2d GL_LINES, point11, point14
				view.drawing_color = "Red"
				point21 = screen_end
				point22 = Geom::Point3d.new screen_end.x,screen_end.y-25,0
				point23 = Geom::Point3d.new screen_end.x-10,screen_end.y-10,0
				point24 = Geom::Point3d.new screen_end.x+10,screen_end.y-10,0
				view.draw2d GL_LINES, point21, point22
				view.draw2d GL_LINES, point21, point23
				view.draw2d GL_LINES, point21, point24
				#---Печатаем координаты центров коннекторов
				a = @pt_begin.to_s
				b = @pt_end.to_s
				point1 = Geom::Point3d.new 5,280,0
				point2 = Geom::Point3d.new 5,300,0
				status1 = view.draw_text point1, $coolpipe_langDriver["Координаты синего коннектора"]+": "+a
				status2 = view.draw_text point2, $coolpipe_langDriver["Координаты красного коннектора"]+": "+b
			end
		end
		def put_otmetka(view,x,y,otmetka_z,pos,color)
			point11 = Geom::Point3d.new x,y,0
			point12 = Geom::Point3d.new x-7,y-10,0
			point13 = Geom::Point3d.new x+7,y-10,0
			point17 = Geom::Point3d.new x-12,y,0
			point18 = Geom::Point3d.new x+12,y,0

			view.line_width = 2
			if pos==0 #левая сторона
				point14 = Geom::Point3d.new x,y-25,0
				point15 = Geom::Point3d.new x-80,y-25,0
				point16 = Geom::Point3d.new x-70,y-42,0
			end
			if pos==1 #правая сторона
				point14 = Geom::Point3d.new x,y-25,0
				point15 = Geom::Point3d.new x+80,y-25,0
				point16 = Geom::Point3d.new x+10,y-42,0
			end
			view.drawing_color = color
			status2 = view.draw2d GL_LINES, point11, point12
			status2 = view.draw2d GL_LINES, point11, point13
			status2 = view.draw2d GL_LINES, point11, point14
			status2 = view.draw2d GL_LINES, point14, point15
			status2 = view.draw2d GL_LINES, point17, point18
			view.drawing_color = "black"
			if otmetka_z>0
				s="+"
			else
				s=""
			end

			z = (((otmetka_z.to_mm*100).round.to_f)/100)
			status2 = view.draw_text point16, s+z.to_s
		end
		def onMouseMove(flags, x, y, view)
			@view = view
			@x = x
			@y = y
			if @component_pipe!=nil
				@name = @component_pipe.get_attribute("CoolPipeComponent","Имя")
			end
		end
		def onLButtonDown(flags, x, y, view)
			get_menu_command(x,y)
			if @active_command!=""
				on_menu_click(@active_command,view)
			else
				@selection.clear
				Sketchup.active_model.select_tool(nil)
				ph = view.pick_helper
				ph.do_pick x,y
				best = ph.best_picked
				if best!=nil
					model = Sketchup.active_model
					selection = model.selection
					status = selection.add best
				end
			end
		end
		def on_menu_click(command,view)
			case command
				when "Редактировать"
					if @cp_edit_pipe_enable ==false
					   @cp_edit_pipe_enable =true
					else
					   @cp_edit_pipe_enable =false
				   end
				when "Изменить диаметры"
					getparams_fromcomponent(@component_pipe)
					$coolpipe_dialogs.cp_selectreducer_dialog(true)
				when "Повернуть на 180°"
					pt1 = @pt_begin.offset @zaxes1.reverse,((@pt_begin-@pt_end).length/2)
					tr1 = Geom::Transformation.new pt1
					vec = @xaxes1.clone
					vec = vec.transform! tr1
					tr2 = Geom::Transformation.rotation pt1, vec, 180.degrees
					@component_pipe.transform! tr2
			end
		end
		def change_diam(param)
			param[:view]=@view
			param[:center]=@pt_begin
			param[:xaxes]=@xaxes1.reverse
			param[:yaxes]=@yaxes1
			@attributes = param.clone
			redrawreducer(param[:view])
		end
		def redrawreducer(view)
			if (@attributes[:center]!=nil) && (@attributes[:xaxes]!=nil) && (@attributes[:yaxes]!=nil)
				model = view.model
				model.start_operation "Редактирование объекта CoolPipe::Reducer"
					@attributes[:view]=view
					@attributes[:Сегментов] = $cp_segments
					layer = @component_pipe.layer
					material = @component_pipe.material
					trans = @component_pipe.transformation
					connectors = Sketchup::CoolPipe::cp_get_connectors_arr(@component_pipe) #Находит все коннекторы объекта
					pt=connectors[0].position.transform!(trans)
					zaxis=connectors[1].position.transform!(trans)-connectors[0].position.transform!(trans)
					axes = zaxis.axes
					vec = axes[0] #xaxes
					drawreducer = ToolDrawReducer.new(@attributes,@component_pipe)
					@component_pipe.erase! if @component_pipe!=nil
					@component_pipe=nil
					@component_pipe=drawreducer.cp_create_reducer_geometry if $cp_vnGeom==true
					@component_pipe=drawreducer.cp_create_cylindr_geometry if $cp_vnGeom==false
					@component_pipe.material = material if material!=nil
					@component_pipe.layer = layer if layer!=nil
					moveOBJ(@component_pipe,pt,vec)
				model.commit_operation
				emulselection(@component_pipe) if @component_pipe!=nil
			end
		end
		def emulselection(obj)
			 @component_pipe = obj
			 status = @selection.add @component_pipe
			 Sketchup.active_model.select_tool ToolEditReducer.new(@name,@component_pipe,@selection)
		end
	end #class ToolEditReducer < ToolEditElement
	######
	class ToolEditTee     < ToolEditElement  #Инструмент редктирования тройника
		def initialize(name,component,selection)
		    super(name,component,selection)
			@passive_color   = "Bisque"
		        @active_color     = "LightGreen"
			getparams_fromcomponent(@component_pipe)
		end
		def reset(view)
		    if( view )
		        view.tooltip = nil
		        view.invalidate if @drawn
		    end
		    @drawn = false
		    @dragging = false
		    @active_command = ""
		    @screen_menu    = []
		    #@pt_begin = nil
		    @pt_center= nil
		    #@pt_end   = nil
		end
		def draw(view)
		    add_menu_item(view,5,5,100,20,$coolpipe_langDriver["Редактировать"],"Редактировать")
		    if @cp_edit_pipe_enable
		        point1 = Geom::Point3d.new 110,5,0
		        status1 = view.draw_text point1, $coolpipe_langDriver["Выделено:"]+@name
		        add_menu_item(view,5,35,140,20,$coolpipe_langDriver["Изменить диаметры"],"Изменить диаметры")
		        draw_visual_tee_info(view)
		    end
			invalidated_view = view.invalidate
		end
		def getparams_fromcomponent(component)
		    @attributes = Sketchup::CoolPipe::cp_getattributes(component)
		    @connectors = Sketchup::CoolPipe::cp_get_connectors_arr(component)
			trans = component.transformation
		    @center_conectors = Sketchup::CoolPipe::cp_get_real_center_connectors(component)
			axes1 = (@center_conectors[0]-@center_conectors[1]).normalize!.axes
			@xaxes1 = axes1[0];@yaxes1 = axes1[1];@zaxes1 = axes1[2];
		end
		def draw_visual_tee_info(view)
		    #---Рисуем тройник
		    pts1=[]
		    pts1 << (Geom::Point3d.new 110,180,0)
		    pts1 << (Geom::Point3d.new 160,180,0)
		    pts1 << (Geom::Point3d.new 180,200,0)
		    pts1 << (Geom::Point3d.new 200,180,0)
		    pts1 << (Geom::Point3d.new 250,180,0)
		    pts1 << (Geom::Point3d.new 250,230,0)
		    pts1 << (Geom::Point3d.new 110,230,0)
		    pts1 << (Geom::Point3d.new 110,180,0)
		    pts2=[]
		    pts2 << (Geom::Point3d.new 160,180,0)
		    pts2 << (Geom::Point3d.new 160,140,0)
		    pts2 << (Geom::Point3d.new 200,140,0)
		    pts2 << (Geom::Point3d.new 200,180,0)
		    view.drawing_color = "blue"
		    view.line_width = 3
		    view.draw2d GL_LINE_STRIP,pts1
		    view.draw2d GL_LINE_STRIP,pts2

		    view.drawing_color = "red"
		    view.line_width = 1
		    pt1 = Geom::Point3d.new 110,205,0
		    pt2 = Geom::Point3d.new 250,205,0
		    pt3 = Geom::Point3d.new 180,140,0
		    pt4 = Geom::Point3d.new 180,200,0
		    view.draw2d GL_LINES, pt1, pt2
		    view.draw2d GL_LINES, pt3, pt4
		    #---Рисуем отметки
		    put_otmetka(view,100,205,@center_conectors[0].z,0,"blue")
		    put_otmetka(view,260,205,@center_conectors[1].z,1,"red")
		    put_otmetka(view,180,140,@center_conectors[2].z,0,"green")
		    #---Отмечаем коннекторы
		    screen_begin = view.screen_coords(@center_conectors[0])
		    screen_end   = view.screen_coords(@center_conectors[1])
		    screen_center= view.screen_coords(@center_conectors[2])
		    view.line_width = 3
		    view.drawing_color = "blue"
		    point11 = screen_begin
		    point12 = Geom::Point3d.new screen_begin.x,screen_begin.y-25,0
		    point13 = Geom::Point3d.new screen_begin.x-10,screen_begin.y-10,0
		    point14 = Geom::Point3d.new screen_begin.x+10,screen_begin.y-10,0
		    view.draw2d GL_LINES, point11, point12
		    view.draw2d GL_LINES, point11, point13
		    view.draw2d GL_LINES, point11, point14
		    view.drawing_color = "red"
		    point21 = screen_end
		    point22 = Geom::Point3d.new screen_end.x,screen_end.y-25,0
		    point23 = Geom::Point3d.new screen_end.x-10,screen_end.y-10,0
		    point24 = Geom::Point3d.new screen_end.x+10,screen_end.y-10,0
		    view.draw2d GL_LINES, point21, point22
		    view.draw2d GL_LINES, point21, point23
		    view.draw2d GL_LINES, point21, point24
		    view.drawing_color = "green"
		    point31 = screen_center
		    point32 = Geom::Point3d.new screen_center.x,screen_center.y-25,0
		    point33 = Geom::Point3d.new screen_center.x-10,screen_center.y-10,0
		    point34 = Geom::Point3d.new screen_center.x+10,screen_center.y-10,0
		    view.draw2d GL_LINES, point31, point32
		    view.draw2d GL_LINES, point31, point33
		    view.draw2d GL_LINES, point31, point34
		    #---Печатаем координаты центров коннекторов
		    a = @center_conectors[0].to_s
		    b = @center_conectors[1].to_s
		    c = @center_conectors[2].to_s
		    point1 = Geom::Point3d.new 5,280,0
		    point2 = Geom::Point3d.new 5,300,0
		    point3 = Geom::Point3d.new 5,320,0
		    status1 = view.draw_text point1, $coolpipe_langDriver["Координаты синего коннектора"]+": "+a
		    status2 = view.draw_text point2, $coolpipe_langDriver["Координаты красного коннектора"]+": "+b
		    status3 = view.draw_text point3, $coolpipe_langDriver["Координаты зеленого коннектора"]+": "+c
		end
		def put_otmetka(view,x,y,otmetka_z,pos,color)
		    point11 = Geom::Point3d.new x,y,0
		    point12 = Geom::Point3d.new x-7,y-10,0
		    point13 = Geom::Point3d.new x+7,y-10,0
		    point17 = Geom::Point3d.new x-12,y,0
		    point18 = Geom::Point3d.new x+12,y,0
		    view.line_width = 2
		    if pos==0 #левая сторона
		        point14 = Geom::Point3d.new x,y-25,0
		        point15 = Geom::Point3d.new x-80,y-25,0
		        point16 = Geom::Point3d.new x-70,y-42,0
		    end
		    if pos==1 #правая сторона
		        point14 = Geom::Point3d.new x,y-25,0
		        point15 = Geom::Point3d.new x+80,y-25,0
		        point16 = Geom::Point3d.new x+10,y-42,0
		    end
		    view.drawing_color = color
		    status2 = view.draw2d GL_LINES, point11, point12
		    status2 = view.draw2d GL_LINES, point11, point13
		    status2 = view.draw2d GL_LINES, point11, point14
		    status2 = view.draw2d GL_LINES, point14, point15
		    status2 = view.draw2d GL_LINES, point17, point18
		    view.drawing_color = "black"
		    if otmetka_z>0;s="+"
		    else;s=""
		    end
		    z = (((otmetka_z.to_mm*100).round.to_f)/100)
		    status2 = view.draw_text point16, s+z.to_s
		end
		def onMouseMove(flags, x, y, view)
		    @view=view;@x=x;@y=y
		    if @component_pipe!=nil
		    @name = @component_pipe.get_attribute("CoolPipeComponent","Имя")
		    end
		end
		def onLButtonDown(flags, x, y, view)
		    get_menu_command(x,y)
		    if @active_command!=""
		        on_menu_click(@active_command,view)
		    else
		        @selection.clear
		        Sketchup.active_model.select_tool(nil)
		        ph = view.pick_helper
		        ph.do_pick x,y
		        best = ph.best_picked
		        if best!=nil
					model = Sketchup.active_model
					selection = model.selection
					status = selection.add best
		        end
		    end
		end
		def on_menu_click(command,view)
		    case command
		        when "Редактировать"
		            if @cp_edit_pipe_enable ==false
		               @cp_edit_pipe_enable =true
		            else
		               @cp_edit_pipe_enable =false
		           end
		        when "Изменить диаметры"
		            getparams_fromcomponent(@component_pipe)
		            $coolpipe_dialogs.cp_selecttee_dialog(change_diametr = true)
		    end
		end
		def change_diam(param)
		    param[:view]=@view
		    param[:center]=@center_conectors[0]
		    param[:xaxes]=@xaxes1.reverse
		    param[:yaxes]=@yaxes1
		    @attributes = param.clone
		    redrawtee(param[:view])
		end
		def redrawtee(view)
		    if (@attributes[:center]!=nil) && (@attributes[:xaxes]!=nil) && (@attributes[:yaxes]!=nil)
				model = view.model
				model.start_operation "Редактирование объекта CoolPipe::Tee"
					trans = @component_pipe.transformation
					@attributes[:view]=view
					@attributes[:Сегментов] = $cp_segments
					layer = @component_pipe.layer
					material = @component_pipe.material
					#connectors = Sketchup::CoolPipe::cp_get_connectors_arr(@component_pipe)
					pt=@center_conectors[0]#connectors[0].position
					zaxis=@center_conectors[1].vector_to @center_conectors[0]
					axes = zaxis.axes
					vec = axes[2] #xaxes
					drawtee = ToolDrawTee.new(@attributes,@component_pipe)
					@component_pipe.erase! if @component_pipe!=nil
					@component_pipe=nil
					@component_pipe=drawtee.cp_create_tee_geometry     if $cp_vnGeom==true
					@component_pipe=drawtee.cp_create_cylindr_geometry if $cp_vnGeom==false
					@component_pipe.material = material if material!=nil
					@component_pipe.layer = layer if layer!=nil
					moveOBJ(@component_pipe,pt,vec)
				model.commit_operation
				emulselection(@component_pipe) if @component_pipe!=nil
		    end
		end
		def emulselection(obj)
		     @component_pipe = obj
		     status = @selection.add @component_pipe
		     Sketchup.active_model.select_tool ToolEditTee.new(@name,@component_pipe,@selection)
		end
	end #class ToolEditTee < ToolEditElement
	######
	class ToolEditCap     < ToolEditElement  #Инструмент редктирования заглушки
		#ВРЕМЕННО ОТМЕНЕН
	end #class ToolEditCap < ToolEditElement
	######
	class ToolEditFlange  < ToolEditElement  #Инструмент редктирования фланца
		#ВРЕМЕННО ОТМЕНЕН
	end #class ToolEditFlange < ToolEditElement
	########################################################################################
	class ToolCopyOptions < CoolPipeTool     #Инструмент "копирование свойств" объектов CoolPipe
		def initialize
			@layer = nil
			@material = nil
			@state = 0
			@bounds = nil
			@color = nil
			@set_bounds = nil
			super()
		end
		################
		def activate
			Sketchup::set_status_text("Выбрать объект CoolPipe - слой и цвет которого нужно скопировать", SB_PROMPT)
			@cursor_id = nil
			cursor_path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/cursors/copy_options_cur.png"))
			if (cursor_path!=nil) or (cursor_path!="")
				@cursor_id = UI.create_cursor(cursor_path, 0, 0)
			end
		end
		def onSetCursor
		   UI.set_cursor(@cursor_id)
		end
		################
		def onCancel(flag, view)
			Sketchup.active_model.select_tool nil
		end
		def enableVCB?
		   return false
		end
		################
		def onMouseMove(flags, x, y, view)
			ph = view.pick_helper
			ph.do_pick x,y
			component = ph.best_picked
			@color = "Blue"   if @state == 0
			@color = "Brown"  if @state == 1
			@bounds = component.bounds if component!=nil
			view.invalidate
		end
		def onLButtonDown(flags, x, y, view)
			ph = view.pick_helper
			ph.do_pick x,y
			component = ph.best_picked
			a=0
			if Sketchup::CoolPipe::cp_iscpcomponent?(component) #если курсор расположен над объектов coolpipe
				if @state == 0
					@layer = component.layer
					@material = component.material
					@state +=1
					Sketchup::set_status_text("Выбрать объект CoolPipe - к которому нужно применить слой и материал", SB_PROMPT)
					a=1
					@set_bounds = component.bounds
				else #@state != -1
					if a==0
						component.layer = @layer if (@layer!=nil) && (component!=nil)
						component.material = @material if (@material!=nil) && (component!=nil)
						#component.definition.entities[0].entities.each do |ent|
						#	ent.layer = @layer if ent.layer.name!="Осевая линия"
						#end
					end
				end
			else # cp_iscpcomponent?(component) == false
				if @state == 0
					@layer = component.layer
					@material = component.material
					@state +=1
					Sketchup::set_status_text("Выбрать объект CoolPipe - к которому нужно применить слой и материал", SB_PROMPT)
					a=1
					@set_bounds = component.bounds
				else #@state != -1
					if a==0
						component.layer = @layer if (@layer!=nil) && (component!=nil)
						component.material = @material if (@material!=nil) && (component!=nil)
					end
				end
			end
		end
		def draw_bound(view,bound,color)
			if (bound!=nil)&&(color!=nil)
				corner = []
				corner << bound.corner(0)
				corner << bound.corner(1)
				corner << bound.corner(2)
				corner << bound.corner(3)
				corner << bound.corner(4)
				corner << bound.corner(5)
				corner << bound.corner(6)
				corner << bound.corner(7)
				view.drawing_color = color
				view.line_width = 2
				view.draw_line corner[0],corner[1] #(left front bottom) | (right front bottom)
				view.draw_line corner[2],corner[3] #(left back bottom)  | (right back bottom)
				view.draw_line corner[4],corner[5] #(left front top)  | (right front top)
				view.draw_line corner[6],corner[7] #(left back top)  | (right back top)
				view.draw_line corner[0],corner[2] #(left front bottom) | (left back bottom)
				view.draw_line corner[0],corner[4] #(left front bottom) | (left front top)
				view.draw_line corner[1],corner[3] #(right front bottom)  | (right front top)
				view.draw_line corner[1],corner[5] #(right front bottom)  | (right front top)
				view.draw_line corner[2],corner[6] #(left back bottom)  | (left back top)
				view.draw_line corner[3],corner[7] #(right back bottom)   | (right back top)
				view.draw_line corner[4],corner[6] #(left front top)  | (left back top)
				view.draw_line corner[5],corner[7] #(right front top)   | (right back top)
			end
		end
		def draw(view)
			draw_bound(view,@bounds,@color)
			draw_bound(view,@set_bounds,"Green")
		end
		################
	end #class ToolCopyOptions
end #module Sketchup::CoolPipe
