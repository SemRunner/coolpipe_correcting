#encoding: utf-8
module Sketchup::CoolPipe


    def self.reload
        original_verbose = $VERBOSE
        $VERBOSE = nil
        pattern = File.join(__dir__, '**/*.rb')
        Dir.glob(pattern).each { |file|
          # Cannot use `Sketchup.load` because its an alias for `Sketchup.require`.
          load file
        }.size
      ensure
		puts "CoolPipe reloaded"
        $VERBOSE = original_verbose
      end

	def self.cp_iscpcomponent?(component)                 #Определяет - является ли component компонентом CoolPipe
		rez = false
		if component!=nil
			rez = true if component.get_attribute("CoolPipeComponent","Тип")!=nil #объект CoolPipe всегда имеет свой "Тип"
		end
		rez
	end
    def self.cp_iscpstandartcomponent?(component) #Метод добавлен в версии 1.4.1(2018)
        res = false
        if component!=nil
            rez = true if (component.get_attribute("CoolPipeComponent","Тип")!=nil)&&(component.get_attribute("CoolPipeComponent","Стандартный_элемент")=="true")
        end
        rez
    end
    def self.checkandAddAtribute(component,attributes,nameattribute) #Метод добавлен в версии 1.4.1(2018) (для сокращения метода cp_getattributes)
        atr = component.get_attribute "CoolPipeComponent", nameattribute
        attributes[nameattribute.to_sym]=atr if atr!=nil
    end
	def self.cp_getattributes(component)   #Получает список аттрибутов компонента CoolPipe #Метод исправлен в версии 1.4.1(2018)
		attributes = {}
		if component!=nil
            checkandAddAtribute(component,attributes,"Тип")
            checkandAddAtribute(component,attributes,"Dнар")
            checkandAddAtribute(component,attributes,"Ду")
            checkandAddAtribute(component,attributes,"стенка")
            checkandAddAtribute(component,attributes,"стенка1")
            checkandAddAtribute(component,attributes,"стенка2")
            checkandAddAtribute(component,attributes,"Теплоизоляция")
            checkandAddAtribute(component,attributes,"ГОСТ")
            checkandAddAtribute(component,attributes,"ЕдИзм")
            checkandAddAtribute(component,attributes,"Имя")
            checkandAddAtribute(component,attributes,"УголОтвода")
            checkandAddAtribute(component,attributes,"РадиусИзгиба")
            checkandAddAtribute(component,attributes,"D1")
            checkandAddAtribute(component,attributes,"D2")
            checkandAddAtribute(component,attributes,"Длина")
            checkandAddAtribute(component,attributes,"масса")
            checkandAddAtribute(component,attributes,"Вариант")
            #-добавка версии 1.4(2018)
            checkandAddAtribute(component,attributes,"Заданпрямуч")
            checkandAddAtribute(component,attributes,"Учетвштуках")
            checkandAddAtribute(component,attributes,"Длинпрямуч")
            #-добавка версии 1.4.1(2018)
            checkandAddAtribute(component,attributes,"Площадь")
            checkandAddAtribute(component,attributes,"L=")
            checkandAddAtribute(component,attributes,"Стандартный_элемент")
            #------------------------
			atr = component.material
			attributes[:Материал]=atr if atr!=nil
			atr = component.layer
			attributes[:Слой]=atr if atr!=nil
		end
		attributes
	end
	def self.cp_isconector?(face)                         #возвращает TRUE если Face - является коннектором CoolPipe
		rez = false
		if face.class==Sketchup::Face
			rez = true if face.get_attribute("CoolPipeComponent","Тип")=="Коннектор" #объект CoolPipe - Коннектор
		end
		rez
	end
	def self.cp_get_connectors_arr(component)             #РЕКУРСИВНАЯ ФУНКЦИЯ Получает все коннекторы объекта, если их нет - то возвращает nil
		connectors = []
		component_class = component.class.to_s
		case component_class
			when "Sketchup::Group"
				component.entities.each{|entity|;connectors = connectors + cp_get_connectors_arr(entity)}
			when "Sketchup::ComponentInstance"
				component.definition.entities.each{|entity|;connectors = connectors + cp_get_connectors_arr(entity)}
			else
				attribute = component.get_attribute("CoolPipeComponent","Коннектор")
				connectors << component if attribute!=nil
		end
		connectors.compact
		connectors
	end
	def self.cp_get_real_center_connectors(component)     #возвращает массив реальных центральных точек коннекторов из component
		connectors = cp_get_connectors_arr(component)
		rez = []
		if connectors!=nil
			connectors.each {|connector|
			point = cp_set_component_transforms(component,connector.position) if connector!=nil
			rez << point if point!=nil
			}
		end
		rez
	end
	def self.cp_set_component_transforms(component,param) #применение трансформаций для param от component (например получение реальных координат центра коннектора)
		if cp_iscpcomponent?(component)
			tr = component.transformation #трансформация компонента для получения абсолютных координат
			param = param.transform! tr
		end
		param
	end
	def self.set_settings_coolpipe
		file_settings = File.join(Sketchup.find_support_file("Plugins/CoolPipe/ini/CoolPipe.ini"))
		File.open(file_settings).each do |line|
			line = line.chomp
			if (line!="") && (line!=" ") && (line!=nil)
				settings = line.split("|")
				$cp_segments      = settings[0].to_i #Количество сегментов
				$cp_elbowK        = settings[1].to_f #Коэффициент построения радиуса отвода от его диаметра
				$cp_elbowPlotnost = settings[2].to_f #Плотность материала для расчета массы отвода [г/см³]
				if (settings[3]=="checked");$cp_vnGeom = true #Строить внутреннюю геометрию
				else;$cp_vnGeom = false;end
				$cp_countThreads  = settings[4].to_i #Количество потоков для расчетов <-- добавлен в версии 1.4.1(2018)
			end
		end
	end
	def self.getFirstElementFromAttribue(component,attribute,element = nil) #РЕКУРСИВНАЯ ФУНКЦИЯ поиска элемента геометрии по заданному атрибуту
		if element==nil
			component_class = component.class.to_s
			case component_class
				when "Sketchup::Group"
					component.entities.each{|entity|;element = getFirstElementFromAttribue(entity,attribute,element)}
				when "Sketchup::ComponentInstance"
					component.definition.entities.each{|entity|;element = getFirstElementFromAttribue(entity,attribute,element)}
				else
					atr = component.get_attribute("CoolPipeComponent",attribute)
					element = component if atr!=nil
			end
		end
		element
	end
	def self.roundf(num,places) #Округление числа с плавающей точкой для совместимости со старыми (2013-2014) (версиями Sketchup
		temp = 10.0**places
		rez= (num*temp).round/temp
		rez
	end
	class ToolbarCoolPipe                                 #Класс для создания Тулбара Coolpipe
		def initialize #Создает тулбар CoolPipe
			icon_path = get_flag_icon_path
			coolpipe_toolbar = UI::Toolbar.new $CoolPipe_version
			coolpipe_toolbar = cp_add_toolbar_button(coolpipe_toolbar,'Труба',   "button_icons/pipe.jpg",    $coolpipe_langDriver['Труба'])    #Кнопка "Труба"
			coolpipe_toolbar = cp_add_toolbar_button(coolpipe_toolbar,'Отвод',   "button_icons/elbows.png",  $coolpipe_langDriver['Отвод'])    #Кнопка "Отвод"
			coolpipe_toolbar = cp_add_toolbar_button(coolpipe_toolbar,'Переход', "button_icons/reducers.png",$coolpipe_langDriver['Переход'])  #Кнопка "Переход"
			coolpipe_toolbar = cp_add_toolbar_button(coolpipe_toolbar,'Тройник', "button_icons/tees.jpg",    $coolpipe_langDriver['Тройник'])  #Кнопка "Тройник"
			coolpipe_toolbar = cp_add_toolbar_button(coolpipe_toolbar,'Заглушка',"button_icons/caps.jpg",    $coolpipe_langDriver['Заглушка']) #Кнопка "Заглушка"
			coolpipe_toolbar = cp_add_toolbar_button(coolpipe_toolbar,'Фланец',  "button_icons/flange.jpg",  $coolpipe_langDriver['Фланец'])   #Кнопка "Фланец"
			coolpipe_toolbar = coolpipe_toolbar.add_separator
			coolpipe_toolbar = cp_add_toolbar_button(coolpipe_toolbar,'+Элемент',"button_icons/Inspections.png",    $coolpipe_langDriver['Превратить в элемент CoolPipe']) #Кнопка "Добавить элемент CoolPipe"
			coolpipe_toolbar = coolpipe_toolbar.add_separator
			coolpipe_toolbar = cp_add_toolbar_button(coolpipe_toolbar,"Редактирование элемента","button_icons/element_edit.png",$coolpipe_langDriver['Редактирование элемента']) #Кнопка "Редактирование элемента"
			coolpipe_toolbar = cp_add_toolbar_button(coolpipe_toolbar,"Копирование свойств","button_icons/copy_options.png",$coolpipe_langDriver['Копирование свойств'])         #Кнопка "Копирование свойств"
			coolpipe_toolbar = cp_add_toolbar_button(coolpipe_toolbar,"Спецификация","button_icons/specification.png",$coolpipe_langDriver['Составить спецификацию CoolPipe'])   #Кнопка "составить спецификацию"
			coolpipe_toolbar = delSUSANbutton(coolpipe_toolbar)
			coolpipe_toolbar = cp_add_toolbar_button(coolpipe_toolbar,"Языковые настройки",icon_path,$coolpipe_langDriver['Языковые настройки CoolPipe']) #Кнопка "Настройки"
			coolpipe_toolbar.show
			Sketchup::CoolPipe::set_settings_coolpipe #Загрузка и установка настроек плагина
		end
		def cp_add_toolbar_button(toolbar,command,icon,text)
			#puts text.to_s
			button = UI::Command.new(command) {
				case command
					when "Труба"
						$coolpipe_dialogs.cp_selectpipe_dialog            #Диалог выбора трубопроводов
					when "Отвод"
						Sketchup.active_model.select_tool ToolDrawElbow.new #Активизация инструмента черчения отвода
					when "Переход"
						$coolpipe_dialogs.cp_selectreducer_dialog         #Диалог выбора переходника
					when "Тройник"
						$coolpipe_dialogs.cp_selecttee_dialog             #Диалог выбора тройника
					when "Заглушка"
						Sketchup.active_model.select_tool ToolDrawCap.new #Активизация инструмента черчения заглушки
					when "Фланец"
						$coolpipe_dialogs.cp_selectflange_dialog          #Диалог выбора фланца
					when "+Элемент"
						$coolpipe_dialogs.cp_add_coolpipe_element_dialog  #Диалог превращения выделенной группы в объект Coolpipe
					when "Редактирование элемента"
						cp_edit_coolpipe_elements
					when "Копирование свойств"
						Sketchup.active_model.select_tool ToolCopyOptions.new #Активизация инструмента "копирование свойств"
					when "Спецификация"
						$coolpipe_dialogs.generate_CoolPipe_specification #Диалог спецификации
					when "Языковые настройки"
						$coolpipe_langDriver.cp_select_and_set_lang       #Диалог выбора языковой локализации проекта
						$coolpipe_langDriver = CP_LanguageHandler.new('coolpipe_lang_driver.strings') #Перезапуск языковых параметров
					when "Исправить геометрию"
					    checkAndRedrawImportGeometry
				end
				}
			button.small_icon = icon
			button.large_icon = icon
			button.tooltip = text
			button.status_bar_text = text
			button.menu_text = text
			toolbar = toolbar.add_item button
			toolbar
		end
		def cp_edit_coolpipe_elements #Редактирование элементов CoolPipe
			selection = Sketchup.active_model.selection
			count = selection.count
			is_component = Sketchup::CoolPipe::cp_iscpcomponent?(selection[0])
			@@cp_edit_pipe_enable  = true
			if (count==1)&&(is_component)
					attributes = Sketchup::CoolPipe::cp_getattributes(selection[0])
					name = attributes[:Имя]
					type = attributes[:Тип]
					if (type!=nil)
						view = Sketchup.active_model.active_view
						case type #Запуск модулей редактирования элементов
							when "Труба"
								$cp_change_pipe_tool = ToolEditPipe.new(name,selection[0],selection)
								Sketchup.active_model.select_tool $cp_change_pipe_tool
							when "Отвод"
								UI.messagebox($coolpipe_langDriver['Редактирование отвода не предусмотрено'])
								#Sketchup.active_model.select_tool ToolEditElbow.new(name,selection[0],selection)
								#Sketchup.active_model.select_tool CP_EditElbowTool.new(name,selection[0],selection)
							when "Переход"
								$cp_change_reducer_tool = ToolEditReducer.new(name,selection[0],selection)
								Sketchup.active_model.select_tool $cp_change_reducer_tool
							when "Тройник"
								$cp_change_tee_tool = ToolEditTee.new(name,selection[0],selection)
								Sketchup.active_model.select_tool $cp_change_tee_tool
							when "Заглушка"
								UI.messagebox($coolpipe_langDriver['Редактирование заглушки не предусмотрено'])
							when "Фланец"
								UI.messagebox($coolpipe_langDriver['Редактирование фланца не предусмотрено'])
						end
					view.invalidate
				end
			else
				UI.messagebox($coolpipe_langDriver["Необходимо выбрать компонент CoolPipe для редактирования"])
			end
		end
		def get_flag_icon_path
			locale = $coolpipe_langDriver.get_active_lang
			case locale
				when "ru"
					icon_path = "button_icons/lang/Russia.png"
				when "en"
					icon_path = "button_icons/lang/United-Kingdom.png"
				when "fr"
					icon_path = "button_icons/lang/France.png"
				when "it"
					icon_path = "button_icons/lang/Italy.png"
				when "de"
					icon_path = "button_icons/lang/Germany.png"
				when "sp"
					icon_path = "button_icons/lang/Spain.png"
				when "ch"
					icon_path = "button_icons/lang/China.png"
				else
					icon_path = "button_icons/settings.png"
			end
			icon_path
		end
		def delSUSANbutton(toolbar)
			delSusanBut = UI::Command.new("Delete Susan, Derrick and purge unused") {
				entities = Sketchup.active_model.entities
				Sketchup.active_model.definitions.purge_unused
				entities.each{|entity|
				if (entity.valid?)and(entity.class==Sketchup::ComponentInstance)
					if ((entity.definition.name.to_s=="Susan")and(entity.definition.description.to_s=="Susan is a member of the SketchUp development team.")) or
					   ((entity.definition.name.to_s=="Derrick")and(entity.definition.description.to_s=="Derrick was a great friend and supporter of SketchUp. He loved spending time with his wife Sharon, his sons Josh, Nick and Will, and his loyal dog Huck.")) or
					   ((entity.definition.name.to_s=="Sophie")and(entity.definition.description.to_s=="Sophie is a member of the SketchUp Pro business development team. She dreams of traveling the world, eating good food and taking pictures of beautiful places.")) or
					   ((entity.definition.name.to_s=="Steve")and(entity.definition.description.to_s=="Paul Stevenson Oles, FAIA, is an architect and co-founder of the American Society of Architectural Illustrators. Steve takes pleasure in long walks, working out, designing all sorts of things, and riding the roads of New Mexico on his beloved '08 Triumph Bonneville.")) or
					   ((entity.definition.name.to_s=="Lisanne")and(entity.definition.description.to_s=="Lisanne is a member of SketchUp's Customer Support Team. When she isn't delivering world class customer support, you will likely find her faux painting walls, columns, beams, and flying buttresses where available. Lisanne also enjoys hiking Colorado's Rocky Mountains with her dog Sky, waterskiing, and capoeira."))or
					   ((entity.definition.name.to_s=="Chris")and(entity.definition.description.to_s=="Chris Dizon joined the SketchUp team in its infancy with @Last Software. His current role is Lead Sales Engineer.  Chris is famous for finding ways to use SketchUp for just about anything.  He's also authored numerous extensions which are available on Extension Warehouse under his user name CMD. When he's not dressing up for Halloween as a banana, he thoroughly enjoys scones, coffee, and the Colorado outdoors.")) or
                       ((entity.definition.name.to_s=="Stacy")and(entity.definition.description.to_s=="Stacy is a Quality Engineer on the SketchUp core team and a native Coloradan. When she’s not looking for bugs in SketchUp, she enjoys hiking and spending time with her family.")) #2018 v.18.0.16975
						entity.erase!
					end
				end;}
			}
			delSusanBut.small_icon = "button_icons/del_Susan.jpg"
			delSusanBut.large_icon = "button_icons/del_Susan.jpg"
			text = $coolpipe_langDriver["Удалить объекты [Сюзан,Детрик,Софи,Стив] и очистка проекта от неиспользуемых объектов"]
			delSusanBut.tooltip = text
			delSusanBut.status_bar_text = text
			delSusanBut.menu_text = text
			toolbar = toolbar.add_item delSusanBut
			toolbar
		end #def delSUSANbutton(toolbar)
	end #class PluginCoolPipe
	class CoolPipeDialogs                                 #В этом классе сосредоточены все диалоги
		###################
		def cp_refreshdialog(dialog,dialogname)          # Обновляет содержимое диалога (переоткрывая его)
			if (dialog!=nil) && (dialog.class==UI::WebDialog)
			   dialog.close
			end
			case dialogname
				when "selectpipe_dialog"
					cp_selectpipe_dialog
				when "selectreducer_dialog"
					cp_selectreducer_dialog
				when "selecttee_dialog"
					cp_selecttee_dialog
				when "selectflange_dialog"
					cp_selectflange_dialog
			end
		end
		def cp_add_coolpipe_element_dialog               # Диалог добавления атрибутов CoolPipe произвольной группе элементов
			model = Sketchup.active_model
			selection = model.selection
			if selection.count>1
				# Сюда вставить блок по предложению об обединений нескольких объектов в группу!!!
			end
			@cppr_selected_obj = selection[0]
			if (@cppr_selected_obj!=nil) && (selection.count==1)
				selclass = @cppr_selected_obj.class
				#puts $coolpipe_langDriver["Класс выделенного объекта = "]+selclass.to_s
				is_cp_obj = Sketchup::CoolPipe::cp_iscpcomponent?(@cppr_selected_obj)
				case is_cp_obj
					when true
						puts $coolpipe_langDriver["Объект является компонентом CoolPipe"]
						UI.messagebox($coolpipe_langDriver["Объект является компонентом CoolPipe"],MB_OK)
						attributes = Sketchup::CoolPipe::cp_getattributes(@cppr_selected_obj)
					when false
						puts $coolpipe_langDriver["Объект не является компонентом CoolPipe"]
				end
				#if is_cp_obj==false #если объект не является компонентом CoolPipe то вызываем диалоговое окно для установки атрибутов CoolPipe
					dlg = UI::WebDialog.new($coolpipe_langDriver["Диалог назначения атрибутов CoolPipe"], true,
					$coolpipe_langDriver["Диалог назначения атрибутов CoolPipe"], 550, 450, 100, 100, true);#width,height,left,top
					@cppr_main_dialog = dlg #глобальная переменная доступа к активному диалогу
					path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/add_coolpipe_element.html"))
					dlg.set_file(path)
					dlg.set_background_color(dlg.get_default_dialog_color)
					dlg.add_action_callback("ValueChanged") {|dialog, params|
						params = dlg.get_element_value("Alt_CallBack") if params==nil
						arr=params.split("|")
						case arr[0]
							when "load_succesfull"
								if is_cp_obj==true
									dlg.execute_script("document.getElementById('Type_').value=\"#{attributes[:Тип]}\"")
									dlg.execute_script("document.getElementById('type_sel').value=\"#{attributes[:Тип]}\"") #Инициация выпадающего списка
									dlg.execute_script("document.getElementById('Ду').value=\"#{attributes[:Ду]}\"")
									dlg.execute_script("document.getElementById('Dнар').value=\"#{attributes[:Dнар]}\"")
									dlg.execute_script("document.getElementById('стенка').value=\"#{attributes[:стенка]}\"")
									dlg.execute_script("document.getElementById('Имя').value=\"#{attributes[:Имя]}\"")
									dlg.execute_script("document.getElementById('ЕдИзм').value=\"#{attributes[:ЕдИзм]}\"")
									dlg.execute_script("document.getElementById('масса').value=\"#{attributes[:масса]}\"")
								end
								#Устанавливаем текущие языковые параметры
								dlg.execute_script("document.getElementById('text_type').innerHTML=\"#{$coolpipe_langDriver["Тип"]}\"")
								dlg.execute_script("document.getElementById('text_diametrUslovniy').innerHTML=\"#{$coolpipe_langDriver["Диаметр условный"]}\"")
								dlg.execute_script("document.getElementById('text_diametrNaruzniy').innerHTML=\"#{$coolpipe_langDriver["Диаметр наружний"]}\"")
								dlg.execute_script("document.getElementById('text_tolsinaStenki').innerHTML=\"#{$coolpipe_langDriver["Толщина стенки"]}\"")
								dlg.execute_script("document.getElementById('text_name').innerHTML=\"#{$coolpipe_langDriver["Наименование"]}\"")
								dlg.execute_script("document.getElementById('text_edIzm').innerHTML=\"#{$coolpipe_langDriver["Единица измерения"]}\"")
								dlg.execute_script("document.getElementById('text_massaEd').innerHTML=\"#{$coolpipe_langDriver["Масса единицы"]}\"")
								dlg.execute_script("document.getElementById('cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
								dlg.execute_script("document.getElementById('save').value=\"#{$coolpipe_langDriver["Сохранить"]}\"")
								dlg.execute_script("document.getElementById('ЕдИзм').value=\"#{$coolpipe_langDriver["шт"]}\"")
								dlg.execute_script("a=\"#{$coolpipe_langDriver["Отвод"]}\";selectbox.options[selectbox.options.length] = new Option(a,a);")
								dlg.execute_script("a=\"#{$coolpipe_langDriver["Переход"]}\";selectbox.options[selectbox.options.length] = new Option(a,a);")
								dlg.execute_script("a=\"#{$coolpipe_langDriver["Тройник"]}\";selectbox.options[selectbox.options.length] = new Option(a,a);")
								dlg.execute_script("a=\"#{$coolpipe_langDriver["Заглушка"]}\";selectbox.options[selectbox.options.length] = new Option(a,a);")
								dlg.execute_script("a=\"#{$coolpipe_langDriver["Фланец"]}\";selectbox.options[selectbox.options.length] = new Option(a,a);")
								dlg.execute_script("a=\"#{$coolpipe_langDriver["Основное оборудование"]}\";selectbox.options[selectbox.options.length] = new Option(a,a);")
								dlg.execute_script("a=\"#{$coolpipe_langDriver["Арматура"]}\";selectbox.options[selectbox.options.length] = new Option(a,a);")
								dlg.execute_script("a=\"#{$coolpipe_langDriver["Другое"]}\";selectbox.options[selectbox.options.length] = new Option(a,a);")
								dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
							when "cancel"
								dlg.close
							when "save"
								attributes = {}
								attributes[:Тип]    = dlg.get_element_value("Type_")
								attributes[:Ду]     = dlg.get_element_value("Ду")
								attributes[:Dнар]   = dlg.get_element_value("Dнар")
								attributes[:стенка] = dlg.get_element_value("стенка")
								attributes[:Имя]    = dlg.get_element_value("Имя")
								attributes[:ЕдИзм]  = dlg.get_element_value("ЕдИзм")
								attributes[:масса]  = dlg.get_element_value("масса")
                                attributes[:Стандартный_элемент]  = "false" #элемент не является стандартным #-добавка версии 1.4.1(2018)
								puts "--------------------------------------------"
								puts $coolpipe_langDriver["Класс созданного объекта"]+@cppr_selected_obj.class.to_s
								#Преобразование группы в компонент добавлено в версии 1.4(2018)
								if @cppr_selected_obj.class==Sketchup::Group
									puts $coolpipe_langDriver["Создаем из группы компонент"]
									#copygroup = @cppr_selected_obj.copy
									@cppr_selected_obj=@cppr_selected_obj.to_component
								end
								puts $coolpipe_langDriver["Получены следующие аттрибуты:"]
								puts "Тип    => "+attributes[:Тип].to_s
								puts "Ду     => "+attributes[:Ду].to_s
								puts "Dнар   => "+attributes[:Dнар].to_s
								puts "стенка => "+attributes[:стенка].to_s
								puts "Имя    => "+attributes[:Имя].to_s
								puts "ЕдИзм  => "+attributes[:ЕдИзм].to_s
								puts "масса  => "+attributes[:масса].to_s
								puts "--------------------------------------------"
								attributes.each_pair do |key, value|
									@cppr_selected_obj.set_attribute "CoolPipeComponent",key.to_s,value.to_s #Присваиваем полученные атрибуты выбранному объекту
								end

                                #Эксперементальный код
								#Добавлено в версии 1.4(2018)
								#entities = model.active_entities
								#groupglob=entities.add_group
								#entities = groupglob.entities
								#group=copygroup.copy
								#attributes.each_pair do |key, value|
								#	group.set_attribute "CoolPipeComponent",key.to_s,value.to_s #Присваиваем полученные атрибуты выбранному объекту
								#end
                                #---------------
                                #Добавлено в версии 1.4(2018)
                                #path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/UserComponents/"))
								#group.definition.save_as "#{path}/#{attributes[:Имя]}.skp" #Сохраняем созданный компонент в библиотеку пользователя
								#puts $coolpipe_langDriver["Созданный компонент сохранен в библиотеке пользователя"]

								#---------------
                                #Добавлено в версии 1.4(2018)
								#Проверка вставки, код вынести отдельно когда будет доработан
								#Для кода разработать диалог выбора объектов. Создать базу для хранения атрибутов CoolPipe для сохраненных объектов
								#path=Sketchup.find_support_file "#{attributes[:Имя]}.skp", "Plugins/CoolPipe/UserComponents/"
								#puts "путь=#{path}"
								#mymodel = Sketchup.active_model
								#mydefinitions = mymodel.import(path)
								#mydefinitions = mymodel.definitions
								#mycomponentdefinition = mydefinitions.load path
								#mymodel.place_component mycomponentdefinition, true

								#---------------

								dlg.close
						end
						}
					dlg.max_height = 450
					dlg.max_width  = 550
					dlg.min_height = 300
					dlg.min_width  = 300
					dlg.set_on_close{@cppr_main_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
					dlg.show_modal
				#end #if @cp_change_list_pipes_du_dialog==nil
			else
				UI.messagebox($coolpipe_langDriver["Необходимо выбрать группу или компонент SketchUp, который необходимо присоединить к CoolPipe"],MB_OK)
				puts $coolpipe_langDriver["Необходимо выбрать один компонент"]
			end
		end #cp_add_coolpipe_element_dialog
		##################################################################################################
		#------- Трубопроводы: --------
		##################################################################################################
		def cp_selectpipe_dialog(change_diametr = false)                #Диалог выбора трубопроводов
			if @cp_activ_selectpipe_dialog==nil
					@dialog_ini = File.join(Sketchup.find_support_file("Plugins/CoolPipe/ini/pipe_dialog.ini"))
					@cp_pipe_database = CP_csv_base.new(File.join(Sketchup.find_support_file("Plugins/CoolPipe/data/pipe_base.csv")))
					@cp_layers_database = CP_csv_base.new(File.join(Sketchup.find_support_file("Plugins/CoolPipe/data/layer_base.csv")))
					dlg = UI::WebDialog.new($coolpipe_langDriver["Выбор трубопровода"], true,$coolpipe_langDriver["Выбор трубопровода"], 475, 450, 100, 100, true);#width,height,left,top
					@cp_activ_selectpipe_dialog = dlg #глобальная переменная доступа к активному диалогу
					path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/select_pipe_dialog.html"))
					dlg.set_file(path)
					dlg.set_background_color(dlg.get_default_dialog_color)
					dlg.add_action_callback("ValueChanged") {|dialog, params|
					if params==nil
						params = dlg.get_element_value("Alt_CallBack")
					end
				arr = params.split("|")
				check_commands_selectpipe_dialog(arr,dlg,change_diametr)  #Проверка и обработка комманд поступающих от диалогового окна
				} # end dlg.add_action_callback
				dlg.max_height = 800
				dlg.max_width  = 500
				dlg.min_height = 450
				dlg.min_width  = 475
				dlg.set_on_close{
				#сохранение последнего состояния окна
				ss_base = dlg.get_element_value("Base_Type")
				ss_doc = dlg.get_element_value("Document_Name")
				ss_du = dlg.get_element_value("Du_Select")
				ss_needlayer = dlg.get_element_value("checked_layers")
				ss_needmaterial = dlg.get_element_value("checked_materials")
				ss_layer = dlg.get_element_value("idlayerselect")
			# ниже добавлено в версии 1.4(2018)
				ss_needHydravl = dlg.get_element_value("checked_Hydravlik") #Необходимость поверочного гидравлического расчета
				ss_heatpower = dlg.get_element_value("ID_heatingpower")
				ss_T1 = dlg.get_element_value("ID_t1")
				ss_T2 = dlg.get_element_value("ID_t2")
				ss_CoolantSel = dlg.get_element_value("Сoolant_Select")
				ss_ksh = dlg.get_element_value("ID_ksh") #Коэффициент шероховатости
				ss_StrTubing = dlg.get_element_value("checked_StraightTubing") #Установить прямой участок для трубопровода
				ss_StrTLength = dlg.get_element_value("ID_LengthStrTubing") #Длина прямого участка
				ss_ConsideredInPieces = dlg.get_element_value("checked_ConsideredInPieces") #Спецификацию считать в штуках по длинам прямых участков
				text = ss_base+"|"+ss_doc+"|"+ss_du+"|"+ss_needlayer+"|"+ss_needmaterial+"|"+ss_layer+"|"+                    #Параметры трубы, слоев и материалов
									ss_needHydravl+"|"+ss_heatpower+"|"+ss_T1+"|"+ss_T2+"|"+ss_CoolantSel+"|"+ss_ksh+"|"+     #Поверочный гидравлический расчет (доб в версии 1.4(2018))
									ss_StrTubing+"|"+ss_StrTLength+"|"+ss_ConsideredInPieces								  #Длина прямого участка (доб в версии 1.4(2018))
				File.open(@dialog_ini, "w") do |file|
					file.puts text
				end
				@cp_activ_selectpipe_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
				dlg.show
			end #if @cp_activ_selectpipe_dialog==nil
		end #def cp_selectpipe_dialog
		def check_commands_selectpipe_dialog(arr,dlg,change_diametr)    #Проверка комманд от диалога добавления наименований документов
			case arr[0]
			###########
				#если окно загруженно заполняем его
				when "load_succesfull"
					typedocs = @cp_pipe_database.get_row_uniq("Тип_документа")
					typedocs.each do |typedoc|
						typedoc = typedoc.chomp
						js_command = "document.getElementById('Base_Type').options[document.getElementById('Base_Type').options.length]=new Option('#{typedoc}','#{typedoc}');"
						dlg.execute_script(js_command) #запоняем список базы данных
					end
					layers = @cp_layers_database.get_layers_name
					layers.each {|layer|
						js_command = "document.getElementById('idlayerselect').options[document.getElementById('idlayerselect').options.length]=new Option('#{layer}','#{layer}');"
						dlg.execute_script(js_command) #запоняем список слоев
					}
					#Версия 1.4(2018)
					js_command  = "document.getElementById('Сoolant_Select').options[document.getElementById('Сoolant_Select').options.length]=new Option('#{$coolpipe_langDriver["Вода "]}[5..190]°C','#{$coolpipe_langDriver["Вода "]}[5..190]°C');"
					js_command += "document.getElementById('Сoolant_Select').options[document.getElementById('Сoolant_Select').options.length]=new Option('#{$coolpipe_langDriver["Пропиленгликоль "]}25%[-10..100]°C','#{$coolpipe_langDriver["Пропиленгликоль "]}25%[-10..100]°C');"
					js_command += "document.getElementById('Сoolant_Select').options[document.getElementById('Сoolant_Select').options.length]=new Option('#{$coolpipe_langDriver["Пропиленгликоль "]}37%[-20..100]°C','#{$coolpipe_langDriver["Пропиленгликоль "]}37%[-20..100]°C');"
					js_command += "document.getElementById('Сoolant_Select').options[document.getElementById('Сoolant_Select').options.length]=new Option('#{$coolpipe_langDriver["Пропиленгликоль "]}45%[-30..100]°C','#{$coolpipe_langDriver["Пропиленгликоль "]}45%[-30..100]°C');"
					js_command += "document.getElementById('Сoolant_Select').options[document.getElementById('Сoolant_Select').options.length]=new Option('#{$coolpipe_langDriver["Этиленгликоль "]}20%[-10..100]°C','#{$coolpipe_langDriver["Этиленгликоль "]}20%[-10..100]°C');"
					js_command += "document.getElementById('Сoolant_Select').options[document.getElementById('Сoolant_Select').options.length]=new Option('#{$coolpipe_langDriver["Этиленгликоль "]}36%[-20..100]°C','#{$coolpipe_langDriver["Этиленгликоль "]}36%[-20..100]°C');"
					js_command += "document.getElementById('Сoolant_Select').options[document.getElementById('Сoolant_Select').options.length]=new Option('#{$coolpipe_langDriver["Этиленгликоль "]}54%[-40..100]°C','#{$coolpipe_langDriver["Этиленгликоль "]}54%[-40..100]°C');"
					rez=dlg.execute_script(js_command) #запоняем список теплоносителей для гидравлического расчета
					#-----------------
					#восстановление предыдущего состояния
					File.open(@dialog_ini).each do |line|
						line = line.chomp
						if (line!="") && (line!=" ") && (line!=nil)
							restore = line.split("|")
							dlg.execute_script("document.getElementById('Base_Type').value=\"#{restore[0]}\"")
							dlg.execute_script("fsetactivebase()")
							dlg.execute_script("document.getElementById('Document_Name').value=\"#{restore[1]}\"")
							dlg.execute_script("fsetactivedocument()")
							dlg.execute_script("document.getElementById('Du_Select').value=\"#{restore[2]}\"")
							dlg.execute_script("fsetactivedu()")
							dlg.execute_script("document.getElementById('idputlayers').checked=#{restore[3]}")
							dlg.execute_script("fcheckassign(document.getElementById('idputlayers'))")
							dlg.execute_script("document.getElementById('idputmaterial').checked=#{restore[4]}")
							dlg.execute_script("fcheckassign(document.getElementById('idputmaterial'))")
							dlg.execute_script("document.getElementById('idlayerselect').value=\"#{restore[5]}\"")
							# Версия 1.4(2018)
							dlg.execute_script("document.getElementById('idHydravlik').checked=#{restore[6]}") #Необходимость поверочного гидравлического расчета
							dlg.execute_script("fcheckHydroassign(document.getElementById('idHydravlik'))")
							dlg.execute_script("document.getElementById('ID_heatingpower').value=\"#{restore[7]}\"")
							dlg.execute_script("document.getElementById('ID_t1').value=\"#{restore[8]}\"")
							dlg.execute_script("document.getElementById('ID_t2').value=\"#{restore[9]}\"")
							dlg.execute_script("document.getElementById('Сoolant_Select').value=\"#{restore[10]}\"")
							dlg.execute_script("document.getElementById('ID_ksh').value=\"#{restore[11]}\"") #Коэффициент шероховатости
							dlg.execute_script("recalc_hydravlick();")
							dlg.execute_script("document.getElementById('idStraightTubing').checked=#{restore[12]}") #Установить прямой участок для трубопровода
							dlg.execute_script("fcheckStraightTubing(document.getElementById('idStraightTubing'))")
							dlg.execute_script("document.getElementById('ID_LengthStrTubing').value=\"#{restore[13]}\"") #Длина прямого участка
							dlg.execute_script("document.getElementById('idConsideredInPiecesCheck').checked=#{restore[14]}") #Спецификацию считать в штуках по длинам прямых участков
							dlg.execute_script("fConsideredInPieces(document.getElementById('idConsideredInPiecesCheck'))")
							#----------------
						end
						#Устанавливаем текущие языковые параметры
						dlg.execute_script("document.getElementById('text_database').innerHTML=\"#{$coolpipe_langDriver["База данных:"]}\"")
						dlg.execute_script("document.getElementById('text_document').innerHTML=\"#{$coolpipe_langDriver["Документ:"]}\"")
						dlg.execute_script("document.getElementById('text_nameofdocument').innerHTML=\"#{$coolpipe_langDriver["Наименование документа"]}\"")
						dlg.execute_script("document.getElementById('text_uslovndiametr').innerHTML=\"#{$coolpipe_langDriver["Условный диаметр:"]}\"")
						dlg.execute_script("document.getElementById('text_nametube').innerHTML=\"#{$coolpipe_langDriver["Наименование:"]}\"")
						dlg.execute_script("document.getElementById('text_needLayers').innerHTML=\"#{$coolpipe_langDriver["Использовать слои"]}\"")
						dlg.execute_script("document.getElementById('text_needmaterials').innerHTML=\"#{$coolpipe_langDriver["Использовать материалы"]}\"")
						#Версия 1.4(2018)
							dlg.execute_script("document.getElementById('text_Hydravlik').innerHTML=\"#{$coolpipe_langDriver["Поверочный гидравлический расчет"]}\"")
							dlg.execute_script("document.getElementById('text_nagruzka').innerHTML=\"#{$coolpipe_langDriver["Нагрузка:"]}\"")
							dlg.execute_script("document.getElementById('text_kWt').innerHTML=\"#{$coolpipe_langDriver["кВт"]}\"")
							dlg.execute_script("document.getElementById('text_heat_transfer_agent').innerHTML=\"#{$coolpipe_langDriver["Теплоноситель:"]}\"")
							dlg.execute_script("document.getElementById('text_roughness').innerHTML=\"#{$coolpipe_langDriver["Коэф.шероховатости:"]}\"")
							dlg.execute_script("document.getElementById('text_Average_density').innerHTML=\"#{$coolpipe_langDriver["Средняя плотность:"]}\"")
							dlg.execute_script("document.getElementById('text_Kinematic_viscosity').innerHTML=\"#{$coolpipe_langDriver["Кинематическая вязкость:"]}\"")
							dlg.execute_script("document.getElementById('text_Rate').innerHTML=\"#{$coolpipe_langDriver["Расход:"]}\"")
							dlg.execute_script("document.getElementById('text_Inner_diameter').innerHTML=\"#{$coolpipe_langDriver["Внутренний диаметр:"]}\"")
							dlg.execute_script("document.getElementById('text_velocity_HTA').innerHTML=\"#{$coolpipe_langDriver["Скорость:"]}\"")
							dlg.execute_script("document.getElementById('text_Reynolds_number').innerHTML=\"#{$coolpipe_langDriver["Число Рейнольдса:"]}\"")
							dlg.execute_script("document.getElementById('text_Coefficient_hydraulic_friction').innerHTML=\"#{$coolpipe_langDriver["Коэффициент гидравлического трения:"]}\"")
							dlg.execute_script("document.getElementById('text_Specific_losses').innerHTML=\"#{$coolpipe_langDriver["Удельные потери:"]}\"")
							dlg.execute_script("document.getElementById('text_StraightTubing').innerHTML=\"#{$coolpipe_langDriver["Установить прямой участок для трубопровода"]}\"")
							dlg.execute_script("document.getElementById('text_Length_of_the_plot').innerHTML=\"#{$coolpipe_langDriver["Длина участка:"]}\"")
							dlg.execute_script("document.getElementById('text_Count_in_pieces').innerHTML=\"#{$coolpipe_langDriver["Считать в штуках:"]}\"")
						#-----------------
						dlg.execute_script("document.getElementById('text_draw').value=\"#{$coolpipe_langDriver["Чертить"]}\"")
						dlg.execute_script("document.getElementById('text_cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
						dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
                        dlg.execute_script("document.getElementById('Сoolant_Select').selectedIndex=0")
                        dlg.execute_script("recalc_hydravlick()")
					end
				###########
				#выбран активный тип документов (например ГОСТ)
				when "set_activ_base"
					name_filter = arr[1]
					name_filter = encode_to_utf8(name_filter)
					namedocs = @cp_pipe_database.get_row_uniq_filter1("Тип_документа",name_filter,"Документ")
					if namedocs.length>0
						namedocs.each do |namedoc|
							if (namedoc!="") && (namedoc!=nil)
								js_command = "document.getElementById('Document_Name').options[document.getElementById('Document_Name').options.length]=new Option('#{namedoc}','#{namedoc}');"
								dlg.execute_script(js_command) #запоняем список базы данных
							end
						end
					end
				###########
				#выбран активный документ из базы
				when "set_activ_document"
					typedoc = arr[1]
					name_filter = arr[2]
					typedoc     = encode_to_utf8(typedoc)
					name_filter = encode_to_utf8(name_filter)
					diametrs = @cp_pipe_database.get_row_uniq_filter2("Тип_документа",typedoc,"Документ",name_filter,"Ду")
					descriptdoc = @cp_pipe_database.get_descript_doc("Документ",name_filter,"Описание_документа")
					js_command = "document.getElementById('Name_DOC').innerHTML=\"#{descriptdoc}\";"
					dlg.execute_script(js_command) #показываем описание документа
					if diametrs.length>0
						diametrs.each do |diametr|
							js_command = "document.getElementById('Du_Select').options[document.getElementById('Du_Select').options.length]=new Option('#{diametr}','#{diametr}');"
							dlg.execute_script(js_command) #запоняем список базы данных
						end
					end
				###########
				when "set_activ_du" #выбран условный диаметр из базы
					typedoc = arr[1]
					docname = arr[2]
					du = arr[3]
					typedoc = encode_to_utf8(typedoc)
					docname = encode_to_utf8(docname)
					du      = encode_to_utf8(du)
					nametube = @cp_pipe_database.get_descript_element("Документ",docname,"Ду",du,"Наименование_трубопровода")
					js_command = "document.getElementById('Name_Pipe').innerHTML=\"#{nametube}\";"
					dlg.execute_script(js_command) #пишем наименование трубы
					#Параметры для гидравлического расчета (диаметр трубы - 2 * тощина стенки = внутренний диаметр)
						base = dlg.get_element_value("Base_Type")
						doc = dlg.get_element_value("Document_Name")
						du = dlg.get_element_value("Du_Select")
						dnar     = @cp_pipe_database.get_tube_params(base,doc,du,"Дн")
						stenka   = @cp_pipe_database.get_tube_params(base,doc,du,"Стенка")
						dvn = dnar.to_f - 2*stenka.to_f;
						js_command = "window.glob_dvn=#{dvn};document.getElementById('TD_dvn').innerHTML=\"#{dvn} мм\";recalc_hydravlick();";
						dlg.execute_script(js_command) #передаем внутренний диаметр трубы в диалог
				###########
				when "change_list_base"
					cp_change_list_pipebase_dialog
				when "change_list_document"
					base = arr[1]
					base = encode_to_utf8(base)
					cp_change_list_pipe_documents_dialog(base)
				when "change_list_pipes_du"
					base = arr[1]
					doc = arr[2]
					base = encode_to_utf8(base)
					doc  = encode_to_utf8(doc)
					cp_change_list_pipes_du(base,doc)
				when "change_list_layers"
					cp_change_list_layers_dialog
				when "cancel"
					dlg.close
				when "draw_pipe" #рисуем трубопровод
					base = dlg.get_element_value("Base_Type")
					doc = dlg.get_element_value("Document_Name")
					du = dlg.get_element_value("Du_Select")
					need_layer = dlg.get_element_value("checked_layers")
					need_material = dlg.get_element_value("checked_materials")
					layer = dlg.get_element_value("idlayerselect") if need_layer=="true"
					layer = nil if need_layer=="false"
					material = @cp_layers_database.get_sketch_color(layer) if (need_material=="true") && (need_layer=="true")
					material = nil if need_material=="false"
					massa    = @cp_pipe_database.get_tube_params(base,doc,du,"Масса")
					dnar     = @cp_pipe_database.get_tube_params(base,doc,du,"Дн")
					stenka   = @cp_pipe_database.get_tube_params(base,doc,du,"Стенка")
					nametube = @cp_pipe_database.get_tube_params(base,doc,du,"Наименование_трубопровода")
                    typetube = "Труба"
					edizm = $coolpipe_langDriver["п.м."]
					#Добавка в v1.4 (2017)
					needStraightTubing = dlg.get_element_value("checked_StraightTubing")     #Установить прямой участок для трубопровода
					lengthStraightTubing = dlg.get_element_value("ID_LengthStrTubing").to_i  #Длина прямого участка
					if (lengthStraightTubing=="")or(lengthStraightTubing==0)
						lengthStraightTubing=1000
					end
					consideredInPieces = dlg.get_element_value("checked_ConsideredInPieces") #Спецификацию считать в штуках по длинам прямых участков
					if (needStraightTubing=="true")and(consideredInPieces=="true")
                        typetube = "Труба"
						edizm = "шт"
					end
					#---------------------
					#nametube =$coolpipe_langDriver["Труба"]+" Ø#{dnar}x#{stenka} #{doc}"
					param={ :Тип            => typetube,     #Тип компонента: труба
							:База           => base,         #Тип базы ГОСТ, ТУ или др...
							:ГОСТ           => doc,          #Нормативный документ (из базы)
							:Ду             => du,           #Диаметр трубопровода условный
							:Имя            => nametube,     #Наименование трубы для спецификации
							:ЕдИзм          => edizm,        #Единица измерения для спецификации
							:масса          => massa,        #Масса единицы для спецификации
							:Dнар           => dnar,         #Диаметр трубопровода наружний
							:стенка         => stenka,       #Толщина стенки трубопровода
							:Установить_слой=> need_layer,   #Флаг установки слоя
							:Установить_материал=> need_material,   #Флаг установки материала
							:Материал       => material,     #Материал трубопровода (собственный цвет из настроек слоев)-если нет то 0
							:Имя_слоя       => layer,        #имя слоя, если нет - то 0
							:Теплоизоляция  => "0",
							:Сегментов      => $cp_segments,
							#Добавка в v1.4 (2017)
							:Заданпрямуч    => needStraightTubing,   # ФЛАГ - Установить прямой участок для трубопровода
							:Длинпрямуч		=> lengthStraightTubing, # Длина прямого участка
							:Учетвштуках    => consideredInPieces    # ФЛАГ - Спецификацию считать в штуках по длинам прямых участков
							}
					dlg.close
					Sketchup.active_model.select_tool ToolDrawPipe.new(param) if change_diametr==false #АКТИВАЦИЯ ТУЛА ЧЕРЧЕНИЯ ТРУБОПРОВОДА
					#Sketchup.active_model.select_tool CP_DrawPipeTool.new(param) if change_diametr==false #старая АКТИВАЦИЯ ТУЛА ЧЕРЧЕНИЯ ТРУБОПРОВОДА
					if change_diametr==true #Изменение диаметра
						$cp_change_pipe_tool.change_diam(param) if $cp_change_pipe_tool!=nil
					end
			end
		end #def check_commands_selectpipe_dialog(arr,dlg,change_diametr)
		###################
		def cp_change_list_pipebase_dialog                              #Диалог редактирования списка баз по трубопроводам ГОСТ/ТУ/DIN и т.д.
			if @cp_activ_changelistpipebase_dialog==nil
			@cp_pipe_database = CP_csv_base.new(File.join(Sketchup.find_support_file("Plugins/CoolPipe/data/pipe_base.csv"))) if @cp_pipe_database==nil #Загружаем базу если она не загруженна
			dlg = UI::WebDialog.new($coolpipe_langDriver["Список баз по трубам"], true,$coolpipe_langDriver["Список баз по трубам"], 350, 350, 100, 100, true);#width,height,left,top
			@cp_activ_changelistpipebase_dialog = dlg #глобальная переменная доступа к активному диалогу
			path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/change_list_pipebase_dialog.html"))
			dlg.set_file(path)
			dlg.set_background_color(dlg.get_default_dialog_color)
			dlg.add_action_callback("ValueChanged") {|dialog, params|
			if params==nil
				params = dlg.get_element_value("Alt_CallBack")
			end
			arr=params.split("|")
			check_commands_change_list_pipebase_dialog(arr,dlg)  #Проверка и обработка комманд поступающих от диалогового окна
			}
			dlg.max_height = 350
			dlg.max_width  = 350
			dlg.min_height = 350
			dlg.min_width  = 350
			dlg.set_on_close{@cp_activ_changelistpipebase_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
			dlg.show
			end #if @cp_activ_changelistpipebase_dialog==nil
		end #cp_change_list_pipebase_dialog
		def check_commands_change_list_pipebase_dialog(arr,dlg)
			case arr[0]
				when "listbase_load_succesfull" #если окно загруженно заполняем его
					typedocs = @cp_pipe_database.get_row_uniq("Тип_документа")
					if typedocs.length>0
						typedocs.each do |typedoc|
							if (typedoc!="") && (typedoc!=nil)
								js_command = "addrow('#{typedoc}')"
								dlg.execute_script(js_command) #запоняем список базы данных
							end
						end
					end
					#Устанавливаем текущие языковые параметры
					 dlg.execute_script("document.getElementById('text_editbases').innerHTML=\"#{$coolpipe_langDriver["Редактирование списка баз"]}\"")
					 dlg.execute_script("document.getElementById('text_typedocuments').innerHTML=\"#{$coolpipe_langDriver["Тип документов"]}\"")
					 dlg.execute_script("text_realdel=\"#{$coolpipe_langDriver["Действительно удалить:"]}\"")
					 dlg.execute_script("document.getElementById('newbase').value=\"#{$coolpipe_langDriver["Новый"]}\"")
					 dlg.execute_script("document.getElementById('cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
					 dlg.execute_script("document.getElementById('save').value=\"#{$coolpipe_langDriver["Сохранить"]}\"")
					 dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
				when "cancel"
					dlg.close
				when "changelistbase"
					#Редактируем список с базами
					for i in 1..(arr.length-1)
						arr[i] = encode_to_utf8(arr[i])
						@cp_pipe_database.add_newtypedoc(arr[i])
					end
					dlg.close
					cp_refreshdialog(@cp_activ_selectpipe_dialog,"selectpipe_dialog")
				when "delete"
					arr[1] = encode_to_utf8(arr[1])
					@cp_pipe_database.delete_typedoc(arr[1])
					cp_refreshdialog(@cp_activ_selectpipe_dialog,"selectpipe_dialog")
			end
		end
		#########
		def cp_change_list_pipe_documents_dialog(base)                  #Диалог редактирования списка документов в соответствующей базе
			if @cp_activ_changelistpipedocuments_dialog==nil
				@cp_pipe_database = CP_csv_base.new(File.join(Sketchup.find_support_file("Plugins/CoolPipe/data/pipe_base.csv"))) if @cp_pipe_database==nil #Загружаем базу если она не загруженна
				dlg = UI::WebDialog.new($coolpipe_langDriver["Список документов по трубам"], true,$coolpipe_langDriver["Список документов по трубам"], 550, 400, 100, 100, true);#width,height,left,top
				@cp_activ_changelistpipedocuments_dialog = dlg #глобальная переменная доступа к активному диалогу
				path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/add_pipe_document_dialog.html"))
				dlg.set_file(path)
				dlg.set_background_color(dlg.get_default_dialog_color)
				dlg.add_action_callback("ValueChanged") {|dialog, params|
				if params==nil
					params = dlg.get_element_value("Alt_CallBack")
				end
				arr=params.split("|")
				check_commands_list_pipe_documents_dialog(arr,arr[0],base,dlg)  #Проверка и обработка комманд поступающих от диалогового окна
				}
				dlg.max_height = 400
				dlg.max_width  = 550
				dlg.min_height = 400
				dlg.min_width  = 550
				dlg.navigation_buttons_enabled = false
				dlg.set_on_close{@cp_activ_changelistpipedocuments_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
				dlg.show
			end #if @cp_activ_changelistpipedocuments_dialog==nil
		end #cp_change_list_pipe_documents_dialog
		def check_commands_list_pipe_documents_dialog(arr,command,base,dlg) #Проверка комманд от диалога добавления наименований документов
			case command
				when "listdocuments_load_succesfull" #если окно загруженно заполняем его
					namedocs = @cp_pipe_database.get_row_uniq_filter1("Тип_документа",base,"Документ")
					if namedocs.length>0
						namedocs.each do |namedoc|
							if (namedoc!="") && (namedoc!=nil)
								descriptdoc = @cp_pipe_database.get_descript_doc("Документ",namedoc,"Описание_документа")
								js_command = "addrow(\"#{namedoc}\",\"#{descriptdoc}\")"
								dlg.execute_script(js_command) #запоняем список базы данных
							end
						end
					end
					#Устанавливаем текущие языковые параметры
					dlg.execute_script("document.getElementById('text_editdoclist').innerHTML=\"#{$coolpipe_langDriver["Редактирование списка документов"]}\"")
					dlg.execute_script("document.getElementById('text_namedoc').innerHTML=\"#{$coolpipe_langDriver["Наименование документа"]}\"")
					dlg.execute_script("document.getElementById('text_descriptdoc').innerHTML=\"#{$coolpipe_langDriver["Описание документа"]}\"")
					dlg.execute_script("text_realdel=\"#{$coolpipe_langDriver["Действительно удалить:"]}\"")
					dlg.execute_script("document.getElementById('newdoc').value=\"#{$coolpipe_langDriver["Новый"]}\"")
					dlg.execute_script("document.getElementById('cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
					dlg.execute_script("document.getElementById('save').value=\"#{$coolpipe_langDriver["Сохранить"]}\"")
					dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
				when "cancel"
					dlg.close
					#@cp_activ_changelistpipedocuments_dialog = nil
				when "skp:ValueChanged@changelistdocuments"
					dlg.close
					#@cp_activ_changelistpipedocuments_dialog = nil
				when "changelistdocuments"
					#Редактируем список с базами
					@cp_activ_changelistpipedocuments_dialog.close
					if arr[1]!="0"
						for i in 1..(arr.length-1)
							arr2 = arr[i].split("=")
							@cp_pipe_database.add_newdoc(base,encode_to_utf8(arr2[0]),encode_to_utf8(arr2[1]))
						end
						cp_refreshdialog(@cp_activ_selectpipe_dialog,"selectpipe_dialog")
					end
					#@cp_activ_changelistpipedocuments_dialog = nil
				when "delete"
					@cp_pipe_database.delete_doc(base,encode_to_utf8(arr[1]))
					cp_refreshdialog(@cp_activ_selectpipe_dialog,"selectpipe_dialog")
			end
		end #check_commands_list_pipe_documents_dialog(command)
		#########
		def cp_change_list_pipes_du(base,doc)                           #Диалог редактирования списка диаметров в документе принадлежащему базе
			if @cp_change_list_pipes_du_dialog==nil
			@cp_pipe_database = CP_csv_base.new(File.join(Sketchup.find_support_file("Plugins/CoolPipe/data/pipe_base.csv"))) if @cp_pipe_database==nil #Загружаем базу если она не загруженна
			dlg = UI::WebDialog.new($coolpipe_langDriver["Список трубопроводов"]+doc, true,$coolpipe_langDriver["Список трубопроводов"], 750, 400, 100, 100, true);#width,height,left,top
			@cp_change_list_pipes_du_dialog = dlg #глобальная переменная доступа к активному диалогу
			path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/add_pipe_element_dialog.html"))
			dlg.set_file(path)
			dlg.set_background_color(dlg.get_default_dialog_color)
			dlg.add_action_callback("ValueChanged") {|dialog, params|
			if params==nil
				params = dlg.get_element_value("Alt_CallBack")
			end
			arr=params.split("|")
			check_commands_change_list_pipes_du(arr,base,doc,dlg)  #Проверка и обработка комманд поступающих от диалогового окна
			}
			dlg.max_height = 400
			dlg.max_width  = 750
			dlg.min_height = 400
			dlg.min_width  = 750
			dlg.set_on_close{@cp_change_list_pipes_du_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
			dlg.show
			end #if @cp_change_list_pipes_du_dialog==nil
		end #cp_change_list_pipes_du
		def check_commands_change_list_pipes_du(arr,base,doc,dlg) #Проверка и обработка комманд поступающих от диалогового окна
			case arr[0]
				when "listdu_load_succesfull" #если окно загруженно заполняем его
					namedu = @cp_pipe_database.get_row_uniq_filter2("Тип_документа",base,"Документ",doc,"Ду")
					if namedu.length>0
						namedu.each do |du|
							namedn = @cp_pipe_database.get_tube_params(base,doc,du,"Дн")
							namest = @cp_pipe_database.get_tube_params(base,doc,du,"Стенка")
							namemas = @cp_pipe_database.get_tube_params(base,doc,du,"Масса")
							namedescript = @cp_pipe_database.get_tube_params(base,doc,du,"Наименование_трубопровода")
							if (du!="") && (du!=nil) #addrow(du,dn,st,mas,name)
								js_command = "addrow(\"#{du}\",\"#{namedn}\",\"#{namest}\",\"#{namemas}\",\"#{namedescript}\")"
								dlg.execute_script(js_command) #запоняем список базы данных
							end
							#Устанавливаем текущие языковые параметры
							dlg.execute_script("document.getElementById('text_editListpipes').innerHTML=\"#{$coolpipe_langDriver["Редактирование списка трубопроводов"]}\"")
							dlg.execute_script("document.getElementById('text_DU').innerHTML=\"#{$coolpipe_langDriver["Диаметр условный"]}\"")
							dlg.execute_script("document.getElementById('text_DN').innerHTML=\"#{$coolpipe_langDriver["Диаметр наружний"]}\"")
							dlg.execute_script("document.getElementById('text_Stenka').innerHTML=\"#{$coolpipe_langDriver["Толщина стенки"]}\"")
							dlg.execute_script("document.getElementById('text_Massa').innerHTML=\"#{$coolpipe_langDriver["Масса"]}\"")
							dlg.execute_script("document.getElementById('text_NameForSpec').innerHTML=\"#{$coolpipe_langDriver["Наименование для спецификации"]}\"")
							dlg.execute_script("text_realdel=\"#{$coolpipe_langDriver["Действительно удалить:"]}\"")
							dlg.execute_script("document.getElementById('newdoc').value=\"#{$coolpipe_langDriver["Новый"]}\"")
							dlg.execute_script("document.getElementById('cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
							dlg.execute_script("document.getElementById('save').value=\"#{$coolpipe_langDriver["Сохранить"]}\"")
							dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
						end
					end
				when "cancel"
					dlg.close
				when "changelistpipeelements"
					#Редактируем список с базами
					@cp_change_list_pipes_du_dialog.close
					arr[1]=encode_to_utf8(arr[1])
					if arr[1]!="0"
						listdu = arr
						listdu = listdu.uniq
						listdu=listdu.collect{|a|a=encode_to_utf8(a)}
						@cp_pipe_database.add_tubes(base,doc,listdu)
						cp_refreshdialog(@cp_activ_selectpipe_dialog,"selectpipe_dialog")
					end
				when "delete"
					@cp_pipe_database.delete_tube(base,doc,encode_to_utf8(arr[1]))
					cp_refreshdialog(@cp_activ_selectpipe_dialog,"selectpipe_dialog")
			end
		end #check_commands_change_list_pipes_du(arr,base,doc,dlg)
		#########
		def cp_change_list_layers_dialog                                #Диалог редактирования списка слоев CoolPipe
			if @cp_change_list_layers_dialog ==nil
			@cp_layers_database = CP_csv_base.new(File.join(Sketchup.find_support_file("Plugins/CoolPipe/data/layer_base.csv"))) if @cp_layers_database==nil #Загружаем базу если она не загруженна
			dlg = UI::WebDialog.new($coolpipe_langDriver["Список слоев CoolPipe"], true,$coolpipe_langDriver["Список слоев CoolPipe"], 725, 600, 100, 100, true);#width,height,left,top
			@cp_change_list_layers_dialog = dlg #глобальная переменная доступа к активному диалогу
			path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/add_layers_dialog.html"))
			dlg.set_file(path)
			dlg.set_background_color(dlg.get_default_dialog_color)
			dlg.add_action_callback("ValueChanged") {|dialog, params|
			if params==nil
				params = dlg.get_element_value("Alt_CallBack")
			end
			arr=params.split("|")
			check_commands_list_layers_dialog(arr,dlg)  #Проверка и обработка комманд поступающих от диалогового окна
			}
			dlg.max_height = 600
			dlg.max_width  = 725
			dlg.min_height = 600
			dlg.min_width  = 725
			dlg.set_on_close{@cp_change_list_layers_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
			dlg.show
			end #if @cp_change_list_layers_dialog==nil
		end #cp_change_list_layers_dialog
		def check_commands_list_layers_dialog(arr,dlg)
			case arr[0]
				when "listlayers_load_succesfull" #если окно загруженно заполняем его
					layers = @cp_layers_database.get_layers_name
					colors = @cp_layers_database.get_colors_HTMLname
					i = 0
					layers.each {|layer|
					js_command = "addrow(\"#{layer}\",\"#{colors[i]}\")"
					dlg.execute_script(js_command) #запоняем список слоев
					i+=1
					}
					#Устанавливаем текущие языковые параметры
					dlg.execute_script("document.getElementById('text_namelayer').innerHTML=\"#{$coolpipe_langDriver["Имя слоя"]}\"")
					dlg.execute_script("document.getElementById('text_color').innerHTML=\"#{$coolpipe_langDriver["Цвет"]}\"")
					dlg.execute_script("document.getElementById('text_selectedcolor').innerHTML=\"#{$coolpipe_langDriver["Выбранный цвет"]}\"")
					dlg.execute_script("text_realdel=\"#{$coolpipe_langDriver["Действительно удалить:"]}\"")
					dlg.execute_script("text_editcolor=\"#{$coolpipe_langDriver["Редактирование цвета слоя"]}\"")
					dlg.execute_script("document.getElementById('newlayer').value=\"#{$coolpipe_langDriver["Новый"]}\"")
					dlg.execute_script("document.getElementById('cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
					dlg.execute_script("document.getElementById('save').value=\"#{$coolpipe_langDriver["Сохранить"]}\"")
					dlg.execute_script("document.getElementById('cancel_color').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
					dlg.execute_script("document.getElementById('save_color').value=\"#{$coolpipe_langDriver["Сохранить"]}\"")
					dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
				when "cancel"
					dlg.close
				when "changelistlayers"
					dlg.close
					layers = []
					for i in arr
						a = encode_to_utf8(i)
						layers << a if a!="changelistlayers"
					end
					@cp_layers_database.save_layers(layers)
					cp_refreshdialog(@cp_activ_selectpipe_dialog,"selectpipe_dialog")
				when "delete"
					@cp_layers_database.delete_layer(name)
					cp_refreshdialog(@cp_activ_selectpipe_dialog,"selectpipe_dialog")
			end
		end #check_commands_list_layers_dialog(arr,dlg)
		##################################################################################################
		#------- Переходы
		##################################################################################################
		def cp_selectreducer_dialog(change_diametr = false) #Диалог выбора переходов
			if @cp_activ_selectreducer_dialog==nil
				dialog_ini = File.join(Sketchup.find_support_file("Plugins/CoolPipe/ini/reducer_dialog.ini"))
				@cp_reducer_database = CP_csv_base.new(File.join(Sketchup.find_support_file("Plugins/CoolPipe/data/reducer_base.csv")))
				dlg = UI::WebDialog.new($coolpipe_langDriver["Выбор перехода"], true,$coolpipe_langDriver["Выбор перехода"], 500, 450, 100, 100, true);#width,height,left,top
				@cp_activ_selectreducer_dialog = dlg #глобальная переменная доступа к активному диалогу
				path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/select_reducer_dialog.html"))
				dlg.set_file(path)
				dlg.set_background_color(dlg.get_default_dialog_color)
				dlg.add_action_callback("ValueChanged") {|dialog, params|
					if params==nil
						params = dlg.get_element_value("Alt_CallBack")
					end
					arr=params.split("|")
					check_commands_selectreducer_dialog(arr,dlg,change_diametr,dialog_ini) #Проверка и обработка комманд поступающих от диалогового окна
				}   #dlg.add_action_callback("ValueChanged") {|dialog, params|
				dlg.max_height = 450
				dlg.max_width  = 500
				dlg.min_height = 450
				dlg.min_width  = 500
				dlg.set_on_close{
				#сохранение последнего состояния окна
				ss_base = dlg.get_element_value("Base_Type")
				ss_doc = dlg.get_element_value("Document_Name")
				ss_du1 = dlg.get_element_value("Du1_Select")
				ss_du2 = dlg.get_element_value("Du2_Select")
				text = ss_base+"|"+ss_doc+"|"+ss_du1+"|"+ss_du2
				File.open(dialog_ini, "w") do |file|
					file.puts text
				end
				@cp_activ_selectreducer_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
				dlg.show
				@typeconnect = "standart"
			end #if @cp_activ_selectreducer_dialog==nil
		end
        def check_commands_selectreducer_dialog(arr,dlg,change_diametr,dialog_ini)
			case arr[0]
				when "load_succesfull"
					typedocs = @cp_reducer_database.get_row_uniq("Тип_документа")
					typedocs.each do |typedoc|
						typedoc = typedoc.chomp
						js_command = "document.getElementById('Base_Type').options[document.getElementById('Base_Type').options.length]=new Option('#{typedoc}','#{typedoc}');"
						dlg.execute_script(js_command) #запоняем список базы данных
					end
					#восстанавливаем последнее состояние диалога
					File.open(dialog_ini).each do |line|
						line = line.chomp
						if (line!="") && (line!=" ") && (line!=nil)
							restore = line.split("|")
							dlg.execute_script("document.getElementById('Base_Type').value=\"#{restore[0]}\"")
							dlg.execute_script("fsetactivebase()")
							dlg.execute_script("document.getElementById('Document_Name').value=\"#{restore[1]}\"")
							dlg.execute_script("fsetactivedocument()")
							dlg.execute_script("document.getElementById('Du1_Select').value=\"#{restore[2]}\"")
							dlg.execute_script("fsetactivedu1()")
							dlg.execute_script("document.getElementById('Du2_Select').value=\"#{restore[3]}\"")
							dlg.execute_script("fsetactivedu2()")
						end
					end
					#Устанавливаем текущие языковые параметры
					dlg.execute_script("document.getElementById('text_database').innerHTML=\"#{$coolpipe_langDriver["База данных"]}\"")
					dlg.execute_script("document.getElementById('text_document').innerHTML=\"#{$coolpipe_langDriver["Документ:"]}\"")
					dlg.execute_script("document.getElementById('text_nameofdocument').innerHTML=\"#{$coolpipe_langDriver["Наименование документа"]}\"")
					dlg.execute_script("document.getElementById('text_DN1').innerHTML=\"#{$coolpipe_langDriver["Ду"]}1\"")
					dlg.execute_script("document.getElementById('text_DN2').innerHTML=\"#{$coolpipe_langDriver["Ду"]}2\"")
					dlg.execute_script("document.getElementById('text_namereducer').innerHTML=\"#{$coolpipe_langDriver["Наименование:"]}\"")
					dlg.execute_script("document.getElementById('type_connect').innerHTML=\"#{$coolpipe_langDriver["Тип присоединения"]}:\"") #Перевести / нужен перевод
					dlg.execute_script("document.getElementById('text_draw').value=\"#{$coolpipe_langDriver["Чертить"]}\"")
					dlg.execute_script("document.getElementById('text_cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
					dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
				when "change_list_base"
					cp_change_list_reduserbase_dialog
				when "change_list_document"
					base = arr[1]
					base = encode_to_utf8(base)
					cp_change_list_reduser_documents_dialog(base)
				when "change_list_reducers"
					base = arr[1]
					doc  = arr[2]
					base = encode_to_utf8(base)
					doc  = encode_to_utf8(doc)
					cp_change_list_redusers(base,doc)
				when "set_activ_base"
					name_filter = arr[1]
					name_filter = encode_to_utf8(name_filter)
					namedocs = @cp_reducer_database.get_row_uniq_filter1("Тип_документа",name_filter,"Документ")
					if namedocs.length>0
						namedocs.each do |namedoc|
							if (namedoc!="") && (namedoc!=nil)
								js_command = "document.getElementById('Document_Name').options[document.getElementById('Document_Name').options.length]=new Option('#{namedoc}','#{namedoc}');"
								dlg.execute_script(js_command) #запоняем список базы данных
							end
						end
					end
				when "set_activ_document"
					typedoc = arr[1]
					name_filter = arr[2]
					typedoc     = encode_to_utf8(typedoc)
					name_filter = encode_to_utf8(name_filter)
					diametrs = @cp_reducer_database.get_row_uniq_filter2("Тип_документа",typedoc,"Документ",name_filter,"DN1")
					descriptdoc = @cp_reducer_database.get_descript_doc("Документ",name_filter,"Описание_документа")
					js_command = "document.getElementById('Name_DOC').innerHTML=\"#{descriptdoc}\";"
					dlg.execute_script(js_command) #показываем описание документа
					if diametrs.length>0
						diametrs.each do |diametr|
							js_command = "document.getElementById('Du1_Select').options[document.getElementById('Du1_Select').options.length]=new Option('#{diametr}','#{diametr}');"
							dlg.execute_script(js_command) #запоняем список базы данных
						end
					end
				when "set_activ_du1"
					typedoc = arr[1]
					name_doc = arr[2]
					du1 = arr[3]
					typedoc  = encode_to_utf8(typedoc)
					name_doc = encode_to_utf8(name_doc)
					du1      = encode_to_utf8(du1)
					diametrs2 = @cp_reducer_database.get_row_uniq_filter3("Тип_документа",typedoc,"Документ",name_doc,"DN1",du1,"DN2")
					if diametrs2.length>0
						diametrs2.each do |diametr|
							js_command = "document.getElementById('Du2_Select').options[document.getElementById('Du2_Select').options.length]=new Option('#{diametr}','#{diametr}');"
							dlg.execute_script(js_command) #запоняем список базы данных
						end
					end
				when "set_activ_du2"
					typedoc = arr[1]
					name_doc = arr[2]
					du1 = arr[3]
					du2 = arr[4]
					typedoc  = encode_to_utf8(typedoc)
					name_doc = encode_to_utf8(name_doc)
					du1      = encode_to_utf8(du1)
					du2      = encode_to_utf8(du2)
					diametrs = @cp_reducer_database.get_row_uniq_filter3("Тип_документа",typedoc,"Документ",name_doc,"DN1",du1,"DN2")
					nametubes = @cp_reducer_database.get_row_uniq_filter3("Тип_документа",typedoc,"Документ",name_doc,"DN1",du1,"Наименование_перехода")
					nametube = ""
					for i in 0..diametrs.length-1
						nametube = nametubes[i] if diametrs[i]==du2
					end
					js_command = "document.getElementById('Name_Reducer').innerHTML=\"#{nametube}\";"
					dlg.execute_script(js_command) #пишем наименование трубы
				when "changetypeconnect" #Способ присоединения перехода: стандарт или от малого диаметра к большому
					@typeconnect = arr[1] # значения "standart" или "smalltobig"
				when "cancel"
					dlg.close
				when "draw_reducer" #рисуем трубопровод
					base = dlg.get_element_value("Base_Type")
					doc = dlg.get_element_value("Document_Name")
					du1 = dlg.get_element_value("Du1_Select")
					du2 = dlg.get_element_value("Du2_Select")
					massa    = @cp_reducer_database.get_reducer_params(base,doc,du1,du2,"massa")
					d1_geom  = @cp_reducer_database.get_reducer_params(base,doc,du1,du2,"D1_geom")
					d2_geom  = @cp_reducer_database.get_reducer_params(base,doc,du1,du2,"D2_geom")
					stenka1  = @cp_reducer_database.get_reducer_params(base,doc,du1,du2,"T1")
					stenka2  = @cp_reducer_database.get_reducer_params(base,doc,du1,du2,"T2")
					length   = @cp_reducer_database.get_reducer_params(base,doc,du1,du2,"L")
					namereducer = @cp_reducer_database.get_reducer_params(base,doc,du1,du2,"Наименование_перехода")
					#namereducer =$coolpipe_langDriver["Переход"]+" К-1-#{d1_geom}x#{stenka1}-#{d2_geom}x#{stenka2} #{doc}"
					param     ={:Тип            => "Переход",   #Тип компонента: Переход
								:Имя            => namereducer, #Наименование Перехода для спецификации
								:ЕдИзм          => $coolpipe_langDriver["шт"],#Единица измерения для спецификации
								:масса          => massa,       #Масса единицы для спецификации
								:D1             => d1_geom,     #Диаметр 1 наружний D1 -> D2
								:D2             => d2_geom,     #Диаметр 2 наружний D1 -> D2
								:Длина          => length,      #Длина перехода
								:Сегментов      => $cp_segments,#Кол-во сегметов окружности
								:стенка1        => stenka1,     #Толщина стенки трубопровода 1
								:стенка2        => stenka2,     #Толщина стенки трубопровода 2
								:ГОСТ           => doc,         #Нормативный документ (из базы)
								:Теплоизоляция  => "0",         #Толщина теплоизоляции мм, если нет то 0
								:Материал       => "0",         #Материал Перехода (собственный цвет из настроек слоев)-если нет то 0
								:typeconstruction=>"concentric",#Тип конструкции концентрический
								:typeconnect	=> @typeconnect #Тип присоединения
								}
					dlg.close
					Sketchup.active_model.select_tool ToolDrawReducer.new(param) if change_diametr==false # АКТИВАЦИЯ ТУЛА ЧЕРЧЕНИЯ ПЕРЕХОДА
					$cp_change_reducer_tool.change_diam(param)                   if change_diametr==true  # Изменение диаметра
			end #case arr[0]
		end
		#########
		def cp_change_list_reduserbase_dialog               #Диалог редактирования списка баз по переходам ГОСТ/ТУ/DIN и т.д.
			if @cp_activ_changelistreducerbase_dialog==nil
			@cp_reducer_database = CP_csv_base.new(File.join(Sketchup.find_support_file("Plugins/CoolPipe/data/reducer_base.csv"))) if @cp_reducer_database==nil #Загружаем базу если она не загруженна
			dlg = UI::WebDialog.new($coolpipe_langDriver["Список баз по переходам"], true,$coolpipe_langDriver["Список баз по переходам"], 300, 300, 100, 100, true);#width,height,left,top
			@cp_activ_changelistreducerbase_dialog = dlg #глобальная переменная доступа к активному диалогу
			path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/change_list_pipebase_dialog.html"))
			dlg.set_file(path)
			dlg.set_background_color(dlg.get_default_dialog_color)
			dlg.add_action_callback("ValueChanged") {|dialog, params|
			if params==nil
				params = dlg.get_element_value("Alt_CallBack")
			end
			arr=params.split("|")
			check_commands_change_list_reduserbase_dialog(arr,dlg) #Проверка и обработка комманд поступающих от диалогового окна
			}
			dlg.max_height = 300
			dlg.max_width  = 300
			dlg.min_height = 300
			dlg.min_width  = 300
			dlg.set_on_close{@cp_activ_changelistreducerbase_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
			dlg.show
			end #if @cp_activ_changelistreducerbase_dialog==nil
		end #cp_change_list_reduserbase_dialog
		def check_commands_change_list_reduserbase_dialog(arr,dlg)
			case arr[0]
				when "listbase_load_succesfull" #если окно загруженно заполняем его
					typedocs = @cp_reducer_database.get_row_uniq("Тип_документа")
					if typedocs.length>0
					typedocs.each do |typedoc|
					if (typedoc!="") && (typedoc!=nil)
					js_command = "addrow('#{typedoc}')"
					dlg.execute_script(js_command) #запоняем список базы данных
					end
					end
					end
					#Устанавливаем текущие языковые параметры
					 dlg.execute_script("document.getElementById('text_editbases').innerHTML=\"#{$coolpipe_langDriver["Редактирование списка баз"]}\"")
					 dlg.execute_script("document.getElementById('text_typedocuments').innerHTML=\"#{$coolpipe_langDriver["Тип документов"]}\"")
					 dlg.execute_script("text_realdel=\"#{$coolpipe_langDriver["Действительно_удалить:"]}\"")
					 dlg.execute_script("document.getElementById('newbase').value=\"#{$coolpipe_langDriver["Новый"]}\"")
					 dlg.execute_script("document.getElementById('cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
					 dlg.execute_script("document.getElementById('save').value=\"#{$coolpipe_langDriver["Сохранить"]}\"")
					 dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
				when "cancel"
					dlg.close
				when "changelistbase"
					#Редактируем список с базами
					for i in 1..(arr.length-1)
						@cp_reducer_database.add_newtypedoc(encode_to_utf8(arr[i]))
					end
					dlg.close
					cp_refreshdialog(@cp_activ_selectreducer_dialog,"selectreducer_dialog")
				when "delete"
					@cp_reducer_database.delete_typedoc(encode_to_utf8(arr[1]))
					cp_refreshdialog(@cp_activ_selectreducer_dialog,"selectreducer_dialog")
			end
		end
		#########
		def cp_change_list_reduser_documents_dialog(base)   #Диалог редактирования списка документов переходов
			if @cp_activ_changelistreducerdocuments_dialog==nil
			@cp_reducer_database = CP_csv_base.new(File.join(Sketchup.find_support_file("Plugins/CoolPipe/data/reducer_base.csv"))) if @cp_reducer_database==nil #Загружаем базу если она не загруженна
			dlg = UI::WebDialog.new($coolpipe_langDriver["Список документов по переходам"], true,$coolpipe_langDriver["Список документов по переходам"], 550, 400, 100, 100, true);#width,height,left,top
			@cp_activ_changelistreducerdocuments_dialog = dlg #глобальная переменная доступа к активному диалогу
			path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/add_pipe_document_dialog.html"))
			dlg.set_file(path)
			dlg.set_background_color(dlg.get_default_dialog_color)
			dlg.add_action_callback("ValueChanged") {|dialog, params|
			if params==nil
				params = dlg.get_element_value("Alt_CallBack")
			end
			arr=params.split("|")
			check_commands_change_list_reduser_documents_dialog(arr,dlg,base)#Проверка и обработка комманд поступающих от диалогового окна
			}
			dlg.max_height = 400
			dlg.max_width  = 550
			dlg.min_height = 400
			dlg.min_width  = 550
			dlg.set_on_close{@cp_activ_changelistreducerdocuments_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
			dlg.show
			end #if @cp_activ_changelistpipedocuments_dialog==nil
		end #cp_change_list_reduser_documents_dialog
		def check_commands_change_list_reduser_documents_dialog(arr,dlg,base)
			case arr[0]
				when "listdocuments_load_succesfull" #если окно загруженно заполняем его
					namedocs = @cp_reducer_database.get_row_uniq_filter1("Тип_документа",base,"Документ")
					if namedocs.length>0
						namedocs.each do |namedoc|
						if (namedoc!="") && (namedoc!=nil)
						descriptdoc = @cp_reducer_database.get_descript_doc("Документ",namedoc,"Описание_документа")
						js_command = "addrow(\"#{namedoc}\",\"#{descriptdoc}\")"
						dlg.execute_script(js_command) #запоняем список базы данных
						end
					end
					end
					#Устанавливаем текущие языковые параметры
					 dlg.execute_script("document.getElementById('text_editdoclist').innerHTML=\"#{$coolpipe_langDriver["Редактирование списка документов"]}\"")
					 dlg.execute_script("document.getElementById('text_namedoc').innerHTML=\"#{$coolpipe_langDriver["Наименование документа"]}\"")
					 dlg.execute_script("document.getElementById('text_descriptdoc').innerHTML=\"#{$coolpipe_langDriver["Описание документа"]}\"")
					 dlg.execute_script("text_realdel=\"#{$coolpipe_langDriver["Действительно удалить:"]}\"")
					 dlg.execute_script("document.getElementById('newdoc').value=\"#{$coolpipe_langDriver["Новый"]}\"")
					 dlg.execute_script("document.getElementById('cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
					 dlg.execute_script("document.getElementById('save').value=\"#{$coolpipe_langDriver["Сохранить"]}\"")
					 dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
				when "cancel"
					dlg.close
				when "skp:ValueChanged@changelistdocuments"
					dlg.close
				when "changelistdocuments"
					#Редактируем список с базами
					dlg.close
					if arr[1]!="0"
						for i in 1..(arr.length-1)
							arr2 = arr[i].split("=")
							@cp_reducer_database.add_newdoc(base,encode_to_utf8(arr2[0]),encode_to_utf8(arr2[1]))
						end
						cp_refreshdialog(@cp_activ_selectreducer_dialog,"selectreducer_dialog")
					end
				when "delete"
					@cp_reducer_database.delete_doc(base,encode_to_utf8(arr[1]))
					cp_refreshdialog(@cp_activ_selectreducer_dialog,"selectreducer_dialog")
			end
		end
		#########
		def cp_change_list_redusers(base,doc)               #Диалог редактирования списка элементов переходов в соотв. документе
			if @cp_change_list_reducers_dialog==nil
			@cp_reducer_database = CP_csv_base.new(File.join(Sketchup.find_support_file("Plugins/CoolPipe/data/reducer_base.csv"))) if @cp_reducer_database==nil #Загружаем базу если она не загруженна
			dlg = UI::WebDialog.new($coolpipe_langDriver["Список элементов в документе "]+doc, true,$coolpipe_langDriver["Список элементов в документе "]+doc, 800, 400, 100, 100, true);#width,height,left,top
			@cp_change_list_reducers_dialog = dlg #глобальная переменная доступа к активному диалогу
			path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/add_reducer_element_dialog.html"))
			dlg.set_file(path)
			dlg.set_background_color(dlg.get_default_dialog_color)
			dlg.add_action_callback("ValueChanged") {|dialog, params|
			enc = true
			if (params==nil) or (params=="changelistreducerselements|readalt")
				enc = false if (params=="changelistreducerselements|readalt")
				params = dlg.get_element_value("Alt_CallBack")
			end
			arr=params.split("|")
			check_commands_change_list_redusers(arr,dlg,base,doc) #Проверка и обработка комманд поступающих от диалогового окна
			}
			dlg.max_height = 400
			dlg.max_width  = 800
			dlg.min_height = 400
			dlg.min_width  = 800
			dlg.set_on_close{@cp_change_list_reducers_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
			dlg.show

			end #if @cp_change_list_reducers_dialog==nil
		end #cp_change_list_redusers(base,doc)
		def check_commands_change_list_redusers(arr,dlg,base,doc)
			case arr[0]
				when "listdu_load_succesfull" #если окно загруженно заполняем его
					namedu1 = @cp_reducer_database.get_row_uniq_filter2("Тип_документа",base,"Документ",doc,"DN1")
					if namedu1.length>0
						namedu1.each do |du1|
							namedu2 = @cp_reducer_database.get_row_uniq_filter3("Тип_документа",base,"Документ",doc,"DN1",du1,"DN2")
							namedu2.each do |du2|
								if (du2!="") && (du2!=nil) #addrow(du,dn,st,mas,name)
									namedn1 = @cp_reducer_database.get_reducer_params(base,doc,du1,du2,"D1_geom")
									namedn2 = @cp_reducer_database.get_reducer_params(base,doc,du1,du2,"D2_geom")
									namest1 = @cp_reducer_database.get_reducer_params(base,doc,du1,du2,"T1")
									namest2 = @cp_reducer_database.get_reducer_params(base,doc,du1,du2,"T2")
									dlina   = @cp_reducer_database.get_reducer_params(base,doc,du1,du2,"L")
									namemas = @cp_reducer_database.get_reducer_params(base,doc,du1,du2,"massa")
									namedescript = @cp_reducer_database.get_reducer_params(base,doc,du1,du2,"Наименование_перехода")
									js_command = "addrow(\"#{du1}\",\"#{du2}\",\"#{namedn1}\",\"#{namedn2}\",\"#{namest1}\",\"#{namest2}\",\"#{dlina}\",\"#{namemas}\",\"#{namedescript}\")"
									dlg.execute_script(js_command) #запоняем список базы данных
								end
							end #namedu2.each do |du2|
					end #namedu1.each do |du1|
					end #if namedu1.length>0
					#Устанавливаем текущие языковые параметры
					dlg.execute_script("document.getElementById('text_editlistreducers').innerHTML=\"#{$coolpipe_langDriver["Редактирование списка переходов"]}\"")
					dlg.execute_script("document.getElementById('text_DiametrUslov1').innerHTML=\"#{$coolpipe_langDriver["Диаметр условный"]} 1\"")
					dlg.execute_script("document.getElementById('text_DiametrUslov2').innerHTML=\"#{$coolpipe_langDriver["Диаметр условный"]} 2\"")
					dlg.execute_script("document.getElementById('text_DiametrNar1').innerHTML=\"#{$coolpipe_langDriver["Диаметр наружний"]} 1\"")
					dlg.execute_script("document.getElementById('text_DiametrNar2').innerHTML=\"#{$coolpipe_langDriver["Диаметр наружний"]} 2\"")
					dlg.execute_script("document.getElementById('text_Stenka1').innerHTML=\"#{$coolpipe_langDriver["Толщина стенки"]} 1\"")
					dlg.execute_script("document.getElementById('text_Stenka2').innerHTML=\"#{$coolpipe_langDriver["Толщина стенки"]} 2\"")
					dlg.execute_script("document.getElementById('text_LengthReducer').innerHTML=\"#{$coolpipe_langDriver["Длина<br>[мм]"]}\"")
					dlg.execute_script("document.getElementById('text_MassaReducer').innerHTML=\"#{$coolpipe_langDriver["Масса"]}\"")
					dlg.execute_script("document.getElementById('text_NameForSpec').innerHTML=\"#{$coolpipe_langDriver["Наименование для спецификации"]}\"")
					dlg.execute_script("text_realdel=\"#{$coolpipe_langDriver["Действительно удалить:"]}\"")
					dlg.execute_script("document.getElementById('newdoc').value=\"#{$coolpipe_langDriver["Новый"]}\"")
					dlg.execute_script("document.getElementById('cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
					dlg.execute_script("document.getElementById('save').value=\"#{$coolpipe_langDriver["Сохранить"]}\"")
					dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
				when "cancel"
					dlg.close
				when "changelistreducerselements"
					#Редактируем список с базами
					@cp_change_list_reducers_dialog.close
					if arr[1]!="0"
						listdu=[]
						for i in 1..arr.length-1
							listdu<<encode_to_utf8(arr[i])
						end
						@cp_reducer_database.add_tubes(base,doc,listdu)
						cp_refreshdialog(@cp_activ_selectreducer_dialog,"selectreducer_dialog")
					end
				when "delete"
					@cp_reducer_database.delete_tube(base,doc,encode_to_utf8(arr[1]))
					cp_refreshdialog(@cp_activ_selectreducer_dialog,"selectreducer_dialog")
			end
		end
		##################################################################################################
		#------- Тройники
		##################################################################################################
		def cp_selecttee_dialog(change_diametr = false)     #Диалог выбора тройников
			if @cp_activ_selecttee_dialog==nil
			dialog_ini = File.join(Sketchup.find_support_file("Plugins/CoolPipe/ini/tee_dialog.ini"))
			@cp_tee_database = CP_csv_base.new(File.join(Sketchup.find_support_file("Plugins/CoolPipe/data/tee_base.csv")))
			dlg = UI::WebDialog.new($coolpipe_langDriver["Выбор тройника"], true,$coolpipe_langDriver["Выбор тройника"], 500, 450, 100, 100, true);#width,height,left,top
			@cp_activ_selecttee_dialog = dlg #глобальная переменная доступа к активному диалогу
			path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/select_tee_dialog.html"))
			dlg.set_file(path)
			dlg.set_background_color(dlg.get_default_dialog_color)
			dlg.add_action_callback("ValueChanged") {|dialog, params|
				if params==nil
					params = dlg.get_element_value("Alt_CallBack")
				end
				arr=params.split("|")
				check_commands_selecttee_dialog(arr,dlg,change_diametr,dialog_ini) #Проверка и обработка комманд поступающих от диалогового окна
			}   #dlg.add_action_callback("ValueChanged") {|dialog, params|
			dlg.max_height = 450
			dlg.max_width  = 500
			dlg.min_height = 450
			dlg.min_width  = 500
			dlg.set_on_close{
			#сохранение последнего состояния окна
			ss_base = dlg.get_element_value("Base_Type")
			ss_doc = dlg.get_element_value("Document_Name")
			ss_du1 = dlg.get_element_value("Du1_Select")
			ss_du2 = dlg.get_element_value("Du2_Select")
			text = ss_base+"|"+ss_doc+"|"+ss_du1+"|"+ss_du2
			File.open(dialog_ini, "w") do |file|
				file.puts text
			end
			@cp_activ_selecttee_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
			dlg.show
			@typeconnect = "standart"
			end #if @cp_activ_selectreducer_dialog==nil
		end
		def check_commands_selecttee_dialog(arr,dlg,change_diametr,dialog_ini)
			case arr[0]
				when "load_succesfull"
					typedocs = @cp_tee_database.get_row_uniq("Тип_документа")
					typedocs.each do |typedoc|
					typedoc = typedoc.chomp
					js_command = "document.getElementById('Base_Type').options[document.getElementById('Base_Type').options.length]=new Option('#{typedoc}','#{typedoc}');"
					dlg.execute_script(js_command) #запоняем список базы данных
					end
					#восстанавливаем последнее состояние диалога
					File.open(dialog_ini).each do |line|
					line = line.chomp
					if (line!="") && (line!=" ") && (line!=nil)
					restore = line.split("|")
					dlg.execute_script("document.getElementById('Base_Type').value=\"#{restore[0]}\"")
					dlg.execute_script("fsetactivebase()")
					dlg.execute_script("document.getElementById('Document_Name').value=\"#{restore[1]}\"")
					dlg.execute_script("fsetactivedocument()")
					dlg.execute_script("document.getElementById('Du1_Select').value=\"#{restore[2]}\"")
					dlg.execute_script("fsetactivedu1()")
					dlg.execute_script("document.getElementById('Du2_Select').value=\"#{restore[3]}\"")
					dlg.execute_script("fsetactivedu2()")
					end
					end
					#Устанавливаем текущие языковые параметры
					dlg.execute_script("document.getElementById('text_database').innerHTML=\"#{$coolpipe_langDriver["База данных"]}\"")
					dlg.execute_script("document.getElementById('text_document').innerHTML=\"#{$coolpipe_langDriver["Документ:"]}\"")
					dlg.execute_script("document.getElementById('text_nameofdocument').innerHTML=\"#{$coolpipe_langDriver["Наименование документа"]}\"")
					dlg.execute_script("document.getElementById('text_DN1').innerHTML=\"#{$coolpipe_langDriver["Ду"]}1\"")
					dlg.execute_script("document.getElementById('text_DN2').innerHTML=\"#{$coolpipe_langDriver["Ду"]}2\"")
					dlg.execute_script("document.getElementById('text_nametee').innerHTML=\"#{$coolpipe_langDriver["Наименование:"]}\"")
					dlg.execute_script("document.getElementById('text_draw').value=\"#{$coolpipe_langDriver["Чертить"]}\"")
					dlg.execute_script("document.getElementById('text_cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
					dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
				when "change_list_base"
					cp_change_list_teebase_dialog
				when "change_list_document"
					base = encode_to_utf8(arr[1])
					cp_change_list_tee_documents_dialog(base)
				when "change_list_reducers"
					base = encode_to_utf8(arr[1])
					doc  = encode_to_utf8(arr[2])
					cp_change_list_tees(base,doc)
				when "set_activ_base"
					name_filter = encode_to_utf8(arr[1])
					namedocs = @cp_tee_database.get_row_uniq_filter1("Тип_документа",name_filter,"Документ")
					if namedocs.length>0
						namedocs.each do |namedoc|
							if (namedoc!="") && (namedoc!=nil)
								js_command = "document.getElementById('Document_Name').options[document.getElementById('Document_Name').options.length]=new Option('#{namedoc}','#{namedoc}');"
								dlg.execute_script(js_command) #запоняем список базы данных
							end
						end
					end
				when "set_activ_document"
					typedoc = encode_to_utf8(arr[1])
					name_filter = encode_to_utf8(arr[2])
					diametrs = @cp_tee_database.get_row_uniq_filter2("Тип_документа",typedoc,"Документ",name_filter,"Ду1")
					descriptdoc = @cp_tee_database.get_descript_doc("Документ",name_filter,"Описание_документа")
					js_command = "document.getElementById('Name_DOC').innerHTML=\"#{descriptdoc}\";"
					dlg.execute_script(js_command) #показываем описание документа
					if diametrs.length>0
						diametrs.each do |diametr|
							js_command = "document.getElementById('Du1_Select').options[document.getElementById('Du1_Select').options.length]=new Option('#{diametr}','#{diametr}');"
							dlg.execute_script(js_command) #запоняем список базы данных
						end
					end
				when "set_activ_du1"
					typedoc = encode_to_utf8(arr[1])
					name_doc = encode_to_utf8(arr[2])
					du1 = arr[3]
					diametrs2 = @cp_tee_database.get_row_uniq_filter3("Тип_документа",typedoc,"Документ",name_doc,"Ду1",du1,"Ду2")
					if diametrs2.length>0
						diametrs2.each do |diametr|
							js_command = "document.getElementById('Du2_Select').options[document.getElementById('Du2_Select').options.length]=new Option('#{diametr}','#{diametr}');"
							dlg.execute_script(js_command) #запоняем список базы данных
						end
					end
				when "set_activ_du2"
					typedoc = encode_to_utf8(arr[1])
					name_doc = encode_to_utf8(arr[2])
					du1 = encode_to_utf8(arr[3])
					du2 = encode_to_utf8(arr[4])
					diametrs = @cp_tee_database.get_row_uniq_filter3("Тип_документа",typedoc,"Документ",name_doc,"Ду1",du1,"Ду2")
					nametubes = @cp_tee_database.get_row_uniq_filter3("Тип_документа",typedoc,"Документ",name_doc,"Ду1",du1,"Наименование_перехода")
					nametube = ""
					for i in 0..diametrs.length-1
						nametube = nametubes[i] if diametrs[i]==du2
					end
					js_command = "document.getElementById('Name_Tee').innerHTML=\"#{nametube}\";"
					dlg.execute_script(js_command) #пишем наименование трубы
				when "changetypeconnect"#Способ присоединения тройника: стандарт или от среднего ответвления
					@typeconnect = arr[1] # значения "standart" или "centerconnect"
				when "cancel"
					dlg.close
				when "draw_tee" #рисуем тройник
					base = dlg.get_element_value("Base_Type")
					doc = dlg.get_element_value("Document_Name")
					du1 = dlg.get_element_value("Du1_Select")
					du2 = dlg.get_element_value("Du2_Select")
					massa    = @cp_tee_database.get_tee_params(base,doc,du1,du2,"Масса")
					d1_geom  = @cp_tee_database.get_tee_params(base,doc,du1,du2,"Дн1")
					d2_geom  = @cp_tee_database.get_tee_params(base,doc,du1,du2,"Дн2")
					stenka1  = @cp_tee_database.get_tee_params(base,doc,du1,du2,"Стенка1")
					stenka2  = @cp_tee_database.get_tee_params(base,doc,du1,du2,"Стенка2")
					length1  = @cp_tee_database.get_tee_params(base,doc,du1,du2,"L1")
					length2  = @cp_tee_database.get_tee_params(base,doc,du1,du2,"L2")
					nametee  = @cp_tee_database.get_tee_params(base,doc,du1,du2,"Наименование_тройника")
					#nametee =$coolpipe_langDriver["Тройник"]+" #{d1_geom}x#{stenka1}-#{d2_geom}x#{stenka2}-#{d1_geom}x#{stenka1} #{doc}"
					param    = {:Тип            => "Тройник",   #Тип компонента: Тройник
								:Имя            => nametee,     #Наименование Тройника для спецификации
								:ЕдИзм          => $coolpipe_langDriver["шт"], #Единица измерения для спецификации
								:масса          => massa,       #Масса единицы для спецификации
								:D1             => d1_geom,     #Диаметр 1 наружний D1 х D2 х D1
								:D2             => d2_geom,     #Диаметр 2 наружний D1 х D2 х D1
								:Dнар           => d1_geom,     #Диаметр 1 наружний D1 х D2 х D1
								:Длина          => length1,     #Длина тройника по большему диаметру
								:Высота         => length2,     #Длина тройника по меньшему диаметру
								:стенка1        => stenka1,     #Толщина стенки трубопровода 1
								:стенка2        => stenka2,     #Толщина стенки трубопровода 2
								:ГОСТ           => doc,         #Нормативный документ (из базы)
								:Теплоизоляция  => "0",         #Толщина теплоизоляции мм, если нет то 0
								:Материал       => "0",         #Материал Тройника (собственный цвет из настроек слоев)-если нет то 0
								:typeconnect	=> @typeconnect #Тип присоединения
								}
					dlg.close
					Sketchup.active_model.select_tool ToolDrawTee.new(param) if change_diametr==false # АКТИВАЦИЯ ТУЛА ЧЕРЧЕНИЯ тройника
					$cp_change_tee_tool.change_diam(param)                   if change_diametr==true  # Изменение диаметра
			end #case arr[0]
		end
		#########
		def cp_change_list_teebase_dialog                   #Диалог редактирования списка баз по тройникам ГОСТ/ТУ/DIN и т.д.
			if @cp_activ_changelistteebase_dialog==nil
			@cp_tee_database = CP_csv_base.new(File.join(Sketchup.find_support_file("Plugins/CoolPipe/data/tee_base.csv"))) if @cp_tee_database==nil #Загружаем базу если она не загруженна
			dlg = UI::WebDialog.new($coolpipe_langDriver["Список баз по тройникам"], true,$coolpipe_langDriver["Список баз по тройникам"], 300, 300, 100, 100, true);#width,height,left,top
			@cp_activ_changelistteebase_dialog = dlg #глобальная переменная доступа к активному диалогу
			path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/change_list_pipebase_dialog.html"))
			dlg.set_file(path)
			dlg.set_background_color(dlg.get_default_dialog_color)
			dlg.add_action_callback("ValueChanged") {|dialog, params|
				if params==nil
					params = dlg.get_element_value("Alt_CallBack")
				end
				arr=params.split("|")
				check_commands_change_list_teebase_dialog(arr,dlg)#Проверка и обработка комманд поступающих от диалогового окна
			}
			dlg.max_height = 300
			dlg.max_width  = 300
			dlg.min_height = 300
			dlg.min_width  = 300
			dlg.set_on_close{@cp_activ_changelistteebase_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
			dlg.show
			end #if @cp_activ_changelistteebase_dialog==nil
		end #cp_change_list_teebase_dialog
		def check_commands_change_list_teebase_dialog(arr,dlg)
			case arr[0]
				when "listbase_load_succesfull" #если окно загруженно заполняем его
					typedocs = @cp_tee_database.get_row_uniq("Тип_документа")
					if typedocs.length>0
						typedocs.each do |typedoc|
							if (typedoc!="") && (typedoc!=nil)
								js_command = "addrow('#{typedoc}')"
								dlg.execute_script(js_command) #запоняем список базы данных
							end
						end
					end
					#Устанавливаем текущие языковые параметры
					 dlg.execute_script("document.getElementById('text_editbases').innerHTML=\"#{$coolpipe_langDriver["Редактирование списка баз"]}\"")
					 dlg.execute_script("document.getElementById('text_typedocuments').innerHTML=\"#{$coolpipe_langDriver["Тип документов"]}\"")
					 dlg.execute_script("text_realdel=\"#{$coolpipe_langDriver["Действительно удалить:"]}\"")
					 dlg.execute_script("document.getElementById('newbase').value=\"#{$coolpipe_langDriver["Новый"]}\"")
					 dlg.execute_script("document.getElementById('cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
					 dlg.execute_script("document.getElementById('save').value=\"#{$coolpipe_langDriver["Сохранить"]}\"")
					 dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
				when "cancel"
					dlg.close
				when "changelistbase"
					#Редактируем список с базами
					for i in 1..(arr.length-1)
						@cp_tee_database.add_newtypedoc(encode_to_utf8(arr[i]))
					end
					dlg.close
					cp_refreshdialog(@cp_activ_selecttee_dialog,"selecttee_dialog")
				when "delete"
					@cp_tee_database.delete_typedoc(encode_to_utf8(arr[1]))
			end
		end
		#########
		def cp_change_list_tee_documents_dialog(base)       #Диалог редактирования списка документов тройников
			if @cp_activ_changelistteedocuments_dialog==nil
			@cp_tee_database = CP_csv_base.new(File.join(Sketchup.find_support_file("Plugins/CoolPipe/data/tee_base.csv"))) if @cp_tee_database==nil #Загружаем базу если она не загруженна
			dlg = UI::WebDialog.new($coolpipe_langDriver["Список документов по тройникам"], true,$coolpipe_langDriver["Список документов по тройникам"], 550, 400, 100, 100, true);#width,height,left,top
			@cp_activ_changelistteedocuments_dialog = dlg #глобальная переменная доступа к активному диалогу
			path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/add_pipe_document_dialog.html"))
			dlg.set_file(path)
			dlg.set_background_color(dlg.get_default_dialog_color)
			dlg.add_action_callback("ValueChanged") {|dialog, params|
			if params==nil
				params = dlg.get_element_value("Alt_CallBack")
			end
			arr=params.split("|")
			check_commands_change_list_tee_documents_dialog(arr,dlg,base) #Проверка и обработка комманд поступающих от диалогового окна
			}
			dlg.max_height = 400
			dlg.max_width  = 550
			dlg.min_height = 400
			dlg.min_width  = 550
			dlg.set_on_close{@cp_activ_changelistteedocuments_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
			dlg.show
			end #if @cp_activ_changelistteedocuments_dialog==nil
		end #cp_change_list_tee_documents_dialog
		def check_commands_change_list_tee_documents_dialog(arr,dlg,base)
			case arr[0]
				when "listdocuments_load_succesfull" #если окно загруженно заполняем его
					namedocs = @cp_tee_database.get_row_uniq_filter1("Тип_документа",base,"Документ")
					if namedocs.length>0
						namedocs.each do |namedoc|
						if (namedoc!="") && (namedoc!=nil)
						descriptdoc = @cp_tee_database.get_descript_doc("Документ",namedoc,"Описание_документа")
						js_command = "addrow(\"#{namedoc}\",\"#{descriptdoc}\")"
						dlg.execute_script(js_command) #запоняем список базы данных
						end
					end
					end
					#Устанавливаем текущие языковые параметры
					 dlg.execute_script("document.getElementById('text_editdoclist').innerHTML=\"#{$coolpipe_langDriver["Редактирование списка документов"]}\"")
					 dlg.execute_script("document.getElementById('text_namedoc').innerHTML=\"#{$coolpipe_langDriver["Наименование документа"]}\"")
					 dlg.execute_script("document.getElementById('text_descriptdoc').innerHTML=\"#{$coolpipe_langDriver["Описание документа"]}\"")
					 dlg.execute_script("text_realdel=\"#{$coolpipe_langDriver["Действительно удалить:"]}\"")
					 dlg.execute_script("document.getElementById('newdoc').value=\"#{$coolpipe_langDriver["Новый"]}\"")
					 dlg.execute_script("document.getElementById('cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
					 dlg.execute_script("document.getElementById('save').value=\"#{$coolpipe_langDriver["Сохранить"]}\"")
					 dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
				when "cancel"
					dlg.close
				when "skp:ValueChanged@changelistdocuments"
					dlg.close
				when "changelistdocuments"
					#Редактируем список с базами
					dlg.close
					if arr[1]!="0"
						for i in 1..(arr.length-1)
							arr2 = arr[i].split("=")
							@cp_tee_database.add_newdoc(base,encode_to_utf8(arr2[0]),encode_to_utf8(arr2[1]))
						end
						cp_refreshdialog(@cp_activ_selecttee_dialog,"selecttee_dialog")
					end
				when "delete"
					@cp_tee_database.delete_doc(base,encode_to_utf8(arr[1]))
					cp_refreshdialog(@cp_activ_selecttee_dialog,"selecttee_dialog")
			end
		end
		#########
		def cp_change_list_tees(base,doc)                   #Диалог редактирования списка элементов тройников в соотв. документе
			if @cp_change_list_tees_dialog==nil
			@cp_tee_database = CP_csv_base.new(File.join(Sketchup.find_support_file("Plugins/CoolPipe/data/tee_base.csv"))) if @cp_tee_database==nil #Загружаем базу если она не загруженна
			dlg = UI::WebDialog.new($coolpipe_langDriver["Список элементов в документе"]+doc, true,$coolpipe_langDriver["Список элементов в документе"]+doc, 880, 400, 100, 100, true);#width,height,left,top
			@cp_change_list_tees_dialog = dlg #глобальная переменная доступа к активному диалогу
			path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/add_tee_element_dialog.html"))
			dlg.set_file(path)
			dlg.set_background_color(dlg.get_default_dialog_color)
			dlg.add_action_callback("ValueChanged") {|dialog, params|
			enc = true
			if (params==nil) or (params=="changelistreducerselements|readalt")
				enc = false if (params=="changelistreducerselements|readalt")
				params = dlg.get_element_value("Alt_CallBack")
			end
			arr=params.split("|")
				check_commands_change_list_tees(arr,dlg,base,doc) #Проверка и обработка комманд поступающих от диалогового окна
			}
			dlg.max_height = 400
			dlg.max_width  = 880
			dlg.min_height = 400
			dlg.min_width  = 880
			dlg.set_on_close{@cp_change_list_tees_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
			dlg.show
			end #if @cp_change_list_tees_dialog==nil
		end #cp_change_list_tees
		def check_commands_change_list_tees(arr,dlg,base,doc)
			case arr[0]
				when "listdu_load_succesfull" #если окно загруженно заполняем его
					namedu1 = @cp_tee_database.get_row_uniq_filter2("Тип_документа",base,"Документ",doc,"Ду1")
					if namedu1.length>0
						namedu1.each do |du1|
							namedu2 = @cp_tee_database.get_row_uniq_filter3("Тип_документа",base,"Документ",doc,"Ду1",du1,"Ду2")
							namedu2.each do |du2|
								if (du2!="") && (du2!=nil) #addrow(du,dn,st,mas,name)
									namedn1 = @cp_tee_database.get_tee_params(base,doc,du1,du2,"Дн1")
									namedn2 = @cp_tee_database.get_tee_params(base,doc,du1,du2,"Дн2")
									dlina1  = @cp_tee_database.get_tee_params(base,doc,du1,du2,"L1")
									dlina2  = @cp_tee_database.get_tee_params(base,doc,du1,du2,"L2")
									namest1 = @cp_tee_database.get_tee_params(base,doc,du1,du2,"Стенка1")
									namest2 = @cp_tee_database.get_tee_params(base,doc,du1,du2,"Стенка2")
									namemas = @cp_tee_database.get_tee_params(base,doc,du1,du2,"Масса")
									namedescript = @cp_tee_database.get_tee_params(base,doc,du1,du2,"Наименование_тройника")
									js_command = "addrow(\"#{du1}\",\"#{du2}\",\"#{namedn1}\",\"#{namedn2}\",\"#{dlina1}\",\"#{dlina2}\",\"#{namest1}\",\"#{namest2}\",\"#{namemas}\",\"#{namedescript}\")"
									dlg.execute_script(js_command) #запоняем список базы данных
								end
							end #namedu2.each do |du2|
						end #namedu1.each do |du1|
					end #if namedu1.length>0
					#Устанавливаем текущие языковые параметры
					dlg.execute_script("document.getElementById('text_editlisttees').innerHTML=\"#{$coolpipe_langDriver["Редактирование списка тройников"]}\"")
					dlg.execute_script("document.getElementById('text_DiametrUslov1').innerHTML=\"#{$coolpipe_langDriver["Диаметр условный"]} 1\"")
					dlg.execute_script("document.getElementById('text_DiametrUslov2').innerHTML=\"#{$coolpipe_langDriver["Диаметр условный"]} 2\"")
					dlg.execute_script("document.getElementById('text_DiametrNar1').innerHTML=\"#{$coolpipe_langDriver["Диаметр наружний"]} 1\"")
					dlg.execute_script("document.getElementById('text_DiametrNar2').innerHTML=\"#{$coolpipe_langDriver["Диаметр наружний"]} 2\"")
					dlg.execute_script("document.getElementById('text_Stenka1').innerHTML=\"#{$coolpipe_langDriver["Толщина стенки"]} 1\"")
					dlg.execute_script("document.getElementById('text_Stenka2').innerHTML=\"#{$coolpipe_langDriver["Толщина стенки"]} 2\"")
					dlg.execute_script("document.getElementById('text_LengthTee1').innerHTML=\"#{$coolpipe_langDriver["Длина [мм]"]} 1\"")
					dlg.execute_script("document.getElementById('text_LengthTee2').innerHTML=\"#{$coolpipe_langDriver["Длина [мм]"]} 2\"")
					dlg.execute_script("document.getElementById('text_MassaTee').innerHTML=\"#{$coolpipe_langDriver["Масса"]}\"")
					dlg.execute_script("document.getElementById('text_NameForSpec').innerHTML=\"#{$coolpipe_langDriver["Наименование для спецификации"]}\"")
					dlg.execute_script("text_realdel=\"#{$coolpipe_langDriver["Действительно удалить:"]}\"")
					dlg.execute_script("document.getElementById('newdoc').value=\"#{$coolpipe_langDriver["Новый"]}\"")
					dlg.execute_script("document.getElementById('cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
					dlg.execute_script("document.getElementById('save').value=\"#{$coolpipe_langDriver["Сохранить"]}\"")
					dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
				when "cancel"
					dlg.close
				when "changelistreducerselements"
					#Редактируем список с базами
					@cp_change_list_tees_dialog.close
					if arr[1]!="0"
						listdu=[]
						for i in 1..arr.length-1
							listdu<<encode_to_utf8(arr[i])
						end
						@cp_tee_database.add_tubes(base,doc,listdu)
						cp_refreshdialog(@cp_activ_selecttee_dialog,"selecttee_dialog")
					end
				when "delete"
					@cp_tee_database.delete_tube(base,doc,encode_to_utf8(arr[1]))
					cp_refreshdialog(@cp_activ_selecttee_dialog,"selecttee_dialog")
			end
		end
		##################################################################################################
		#------- Фланцы
		##################################################################################################
		def cp_selectflange_dialog(change_diametr = false)  #Диалог выбора Фланцев
			if @cp_activ_selectflange_dialog==nil
				dialog_ini = File.join(Sketchup.find_support_file("Plugins/CoolPipe/ini/flange_dialog.ini"))
				@cp_flange_database = CP_csv_base.new(File.join(Sketchup.find_support_file("Plugins/CoolPipe/data/flange_base.csv")))
				dlg = UI::WebDialog.new($coolpipe_langDriver["Выбор фланца"], true,$coolpipe_langDriver["Выбор фланца"], 500, 450, 100, 100, true);#width,height,left,top
				@cp_activ_selectflange_dialog = dlg #глобальная переменная доступа к активному диалогу
				path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/select_flange_dialog.html"))
				dlg.set_file(path)
				dlg.set_background_color(dlg.get_default_dialog_color)
				dlg.add_action_callback("ValueChanged") {|dialog, params|
					if params==nil
						params = dlg.get_element_value("Alt_CallBack")
					end
					arr=params.split("|")
					check_commands_selectflange_dialog(arr,dlg,change_diametr,dialog_ini) #Проверка и обработка комманд поступающих от диалогового окна
				} # end dlg.add_action_callback
				dlg.max_height = 450
				dlg.max_width  = 500
				dlg.min_height = 450
				dlg.min_width  = 500
				dlg.set_on_close{
				#сохранение последнего состояния окна
				ss_base = dlg.get_element_value("Base_Type")
				ss_doc = dlg.get_element_value("Document_Name")
				ss_du = dlg.get_element_value("Du_Select")
				text = ss_base+"|"+ss_doc+"|"+ss_du
				File.open(dialog_ini, "w") do |file|
					file.puts text
				end
				@cp_activ_selectflange_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
				dlg.show
			end #if @cp_activ_selectpipe_dialog==nil
		end #def cp_selectpipe_dialog
		def check_commands_selectflange_dialog(arr,dlg,change_diametr,dialog_ini)
			case arr[0]
				###########
				#если окно загруженно заполняем его
				when "load_succesfull"
					typedocs = @cp_flange_database.get_row_uniq("Тип_документа")
						typedocs.each do |typedoc|
						typedoc = typedoc.chomp
						js_command = "document.getElementById('Base_Type').options[document.getElementById('Base_Type').options.length]=new Option('#{typedoc}','#{typedoc}');"
						dlg.execute_script(js_command) #запоняем список базы данных
					end
					#восстановление предыдущего состояния
					File.open(dialog_ini).each do |line|
						line = line.chomp
						if (line!="") && (line!=" ") && (line!=nil)
							restore = line.split("|")
							dlg.execute_script("document.getElementById('Base_Type').value=\"#{restore[0]}\"")
							dlg.execute_script("fsetactivebase()")
							dlg.execute_script("document.getElementById('Document_Name').value=\"#{restore[1]}\"")
							dlg.execute_script("fsetactivedocument()")
							dlg.execute_script("document.getElementById('Du_Select').value=\"#{restore[2]}\"")
							dlg.execute_script("fsetactivedu()")
						end
					end
					#Устанавливаем текущие языковые параметры
					dlg.execute_script("document.getElementById('text_database').innerHTML=\"#{$coolpipe_langDriver["База данных"]}\"")
					dlg.execute_script("document.getElementById('text_document').innerHTML=\"#{$coolpipe_langDriver["Документ:"]}\"")
					dlg.execute_script("document.getElementById('text_nameofdocument').innerHTML=\"#{$coolpipe_langDriver["Наименование документа"]}\"")
					dlg.execute_script("document.getElementById('text_uslovndiametr').innerHTML=\"#{$coolpipe_langDriver["Условный диаметр:"]}\"")
					dlg.execute_script("document.getElementById('text_nametube').innerHTML=\"#{$coolpipe_langDriver["Наименование:"]}\"")
					dlg.execute_script("document.getElementById('text_draw').value=\"#{$coolpipe_langDriver["Чертить"]}\"")
					dlg.execute_script("document.getElementById('text_cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
					dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
				###########
				#выбрана выбран активный тип документов (например ГОСТ)
				when "set_activ_base"
					name_filter = encode_to_utf8(arr[1])
					namedocs = @cp_flange_database.get_row_uniq_filter1("Тип_документа",name_filter,"Документ")
					if namedocs.length>0
						namedocs.each do |namedoc|
							if (namedoc!="") && (namedoc!=nil)
								js_command = "document.getElementById('Document_Name').options[document.getElementById('Document_Name').options.length]=new Option('#{namedoc}','#{namedoc}');"
								dlg.execute_script(js_command) #запоняем список базы данных
							end
						end
					end
				###########
				#выбран активный документ из базы
				when "set_activ_document"
					typedoc = encode_to_utf8(arr[1])
					name_filter = encode_to_utf8(arr[2])
					diametrs = @cp_flange_database.get_row_uniq_filter2("Тип_документа",typedoc,"Документ",name_filter,"Ду")
					descriptdoc = @cp_flange_database.get_descript_doc("Документ",name_filter,"Описание_документа")
					js_command = "document.getElementById('Name_DOC').innerHTML=\"#{descriptdoc}\";"
					dlg.execute_script(js_command) #показываем описание документа
					if diametrs.length>0
						diametrs.each do |diametr|
							js_command = "document.getElementById('Du_Select').options[document.getElementById('Du_Select').options.length]=new Option('#{diametr}','#{diametr}');"
							dlg.execute_script(js_command) #запоняем список базы данных
						end
					end
				###########
				when "set_activ_du" #выбран условный диаметр из базы
					typedoc = encode_to_utf8(arr[1])
					docname = encode_to_utf8(arr[2])
					du = encode_to_utf8(arr[3])
					nametube = @cp_flange_database.get_descript_element("Документ",docname,"Ду",du,"Наименование_фланца")
					js_command = "document.getElementById('Name_Flange').innerHTML=\"#{nametube}\";"
					dlg.execute_script(js_command) #пишем наименование трубы
				###########
				when "change_list_base"
					cp_change_list_flangebase_dialog
				when "change_list_document"
					base = encode_to_utf8(arr[1])
					cp_change_list_flange_documents_dialog(base)
				when "change_list_pipes_du"
					base = encode_to_utf8(arr[1])
					doc = encode_to_utf8(arr[2])
					cp_change_list_flanges(base,doc)
				when "cancel"
					dlg.close
				when "draw_flange" #рисуем трубопровод
					base = dlg.get_element_value("Base_Type")
					doc = dlg.get_element_value("Document_Name")
					du = dlg.get_element_value("Du_Select")
					du       = @cp_flange_database.get_flange_params(base,doc,du,"Ду")
					d        = @cp_flange_database.get_flange_params(base,doc,du,"d")
					n        = @cp_flange_database.get_flange_params(base,doc,du,"n")
					d1       = @cp_flange_database.get_flange_params(base,doc,du,"D1")
					d2       = @cp_flange_database.get_flange_params(base,doc,du,"D2")
					d3       = @cp_flange_database.get_flange_params(base,doc,du,"D3")
					d4       = @cp_flange_database.get_flange_params(base,doc,du,"D4")
					d5       = @cp_flange_database.get_flange_params(base,doc,du,"D5") #Расположение болтового отверстия - при содействии Nemesis
					h1       = @cp_flange_database.get_flange_params(base,doc,du,"h1")
					h2       = @cp_flange_database.get_flange_params(base,doc,du,"h2")
					h3       = @cp_flange_database.get_flange_params(base,doc,du,"h3")
					nameflange = @cp_flange_database.get_flange_params(base,doc,du,"Наименование_трубопровода")
					st = 2    if  d1.to_f<32
					st = 3.5  if (d1.to_f>32) &&(d1.to_f<=90)
					st = 4    if (d1.to_f>90) &&(d1.to_f<=160)
					st = 6    if (d1.to_f>160)&&(d1.to_f<=390)
					st = 7    if (d1.to_f>390)&&(d1.to_f<=700)
					st = 8    if (d1.to_f>700)&&(d1.to_f<=990)
					st = 11   if (d1.to_f>990)&&(d1.to_f<=1190)
					st = 12   if  d1.to_f>1190
					#nameflange =$coolpipe_langDriver["Фланец"]+" Ду=#{du} #{doc}"
					param={:Тип            => "Фланец",     #Тип компонента: Фланец
						   :База           => base,         #Тип базы ГОСТ, ТУ или др...
						   :ГОСТ           => doc,          #Нормативный документ (из базы)
						   :Ду             => du,           #Диаметр трубопровода условный
						   :Имя            => nameflange,   #Наименование трубы для спецификации
						   :ЕдИзм          => $coolpipe_langDriver["шт"], #Единица измерения для спецификации
						   :масса          => "?",          #Масса единицы для спецификации
						   :Dнар           => d1,           #Диаметр трубопровода наружний
						   :стенка         => st,
						   :Cегментов      => $cp_segments,
						   :D1             => d1,
						   :D2             => d2,
						   :D3             => d3,
						   :D4             => d4,
						   :D5			   => d5, #Расположение болтового отверстия - при содействии Nemesis
						   :h1             => h1,
						   :h2             => h2,
						   :h3             => h3,
						   :n_отв          => n,
						   :d_отв          => d
						  }
					dlg.close
					Sketchup.active_model.select_tool ToolDrawFlange.new(param) if change_diametr==false #АКТИВАЦИЯ ТУЛА ЧЕРЧЕНИЯ Фланца
			end
		end
		#########
		def cp_change_list_flangebase_dialog                #Диалог редактирования списка баз по фланцам ГОСТ/ТУ/DIN и т.д.
			if @cp_activ_changelistflangebase_dialog==nil
			@cp_flange_database = CP_csv_base.new(File.join(Sketchup.find_support_file("Plugins/CoolPipe/data/flange_base.csv"))) if @cp_flange_database==nil #Загружаем базу если она не загруженна
			dlg = UI::WebDialog.new($coolpipe_langDriver["Список баз по фланцам"], true,$coolpipe_langDriver["Список баз по фланцам"], 300, 300, 100, 100, true);#width,height,left,top
			@cp_activ_changelistflangebase_dialog = dlg #глобальная переменная доступа к активному диалогу
			path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/change_list_pipebase_dialog.html"))
			dlg.set_file(path)
			dlg.set_background_color(dlg.get_default_dialog_color)
			dlg.add_action_callback("ValueChanged") {|dialog, params|
			if params==nil
				params = dlg.get_element_value("Alt_CallBack")
			end
			arr=params.split("|")
			check_commands_change_list_flangebase_dialog(arr,dlg) #Проверка и обработка комманд поступающих от диалогового окна
			}
			dlg.max_height = 300
			dlg.max_width  = 300
			dlg.min_height = 300
			dlg.min_width  = 300
			dlg.set_on_close{@cp_activ_changelistflangebase_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
			dlg.show
			end #if @cp_activ_changelistflangebase_dialog==nil
		end #cp_change_list_flangebase_dialog
		def check_commands_change_list_flangebase_dialog(arr,dlg)
			case arr[0]
				when "listbase_load_succesfull" #если окно загруженно заполняем его
					typedocs = @cp_flange_database.get_row_uniq("Тип_документа")
					if typedocs.length>0
						typedocs.each do |typedoc|
							if (typedoc!="") && (typedoc!=nil)
								js_command = "addrow('#{typedoc}')"
								dlg.execute_script(js_command) #запоняем список базы данных
							end
						end
					end
					#Устанавливаем текущие языковые параметры
					 dlg.execute_script("document.getElementById('text_editbases').innerHTML=\"#{$coolpipe_langDriver["Редактирование списка баз"]}\"")
					 dlg.execute_script("document.getElementById('text_typedocuments').innerHTML=\"#{$coolpipe_langDriver["Тип документов"]}\"")
					 dlg.execute_script("text_realdel=\"#{$coolpipe_langDriver["Действительно удалить"]}\"")
					 dlg.execute_script("document.getElementById('newbase').value=\"#{$coolpipe_langDriver["Новый"]}\"")
					 dlg.execute_script("document.getElementById('cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
					 dlg.execute_script("document.getElementById('save').value=\"#{$coolpipe_langDriver["Сохранить"]}\"")
					 dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
				when "cancel"
					dlg.close
				when "changelistbase"
					#Редактируем список с базами
					for i in 1..(arr.length-1)
						@cp_flange_database.add_newtypedoc(encode_to_utf8(arr[i]))
					end
					dlg.close
					cp_refreshdialog(@cp_activ_selectflange_dialog,"selectflange_dialog")
				when "delete"
					@cp_flange_database.delete_typedoc(encode_to_utf8(arr[1]))
			end
		end
		#########
		def cp_change_list_flange_documents_dialog(base)    #Диалог редактирования списка документов фланцев
			if @cp_activ_changelistflangedocuments_dialog==nil
				@cp_flange_database = CP_csv_base.new(File.join(Sketchup.find_support_file("Plugins/CoolPipe/data/flange_base.csv"))) if @cp_flange_database==nil #Загружаем базу если она не загруженна
				dlg = UI::WebDialog.new($coolpipe_langDriver["Список документов по фланцам"], true,$coolpipe_langDriver["Список документов по фланцам"], 550, 400, 100, 100, true);#width,height,left,top
				@cp_activ_changelistflangedocuments_dialog = dlg #глобальная переменная доступа к активному диалогу
				path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/add_pipe_document_dialog.html"))
				dlg.set_file(path)
				dlg.set_background_color(dlg.get_default_dialog_color)
				dlg.add_action_callback("ValueChanged") {|dialog, params|
					if params==nil
						params = dlg.get_element_value("Alt_CallBack")
					end
					arr=params.split("|")
					check_commands_change_list_flange_documents_dialog(arr,dlg,base) #Проверка и обработка комманд поступающих от диалогового окна
				}
				dlg.max_height = 400
				dlg.max_width  = 550
				dlg.min_height = 400
				dlg.min_width  = 550
				dlg.set_on_close{@cp_activ_changelistflangedocuments_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
				dlg.show
			end #if @cp_activ_changelistteedocuments_dialog==nil
		end
		def check_commands_change_list_flange_documents_dialog(arr,dlg,base)
			case arr[0]
				when "listdocuments_load_succesfull" #если окно загруженно заполняем его
					namedocs = @cp_flange_database.get_row_uniq_filter1("Тип_документа",base,"Документ")
					if namedocs.length>0
						namedocs.each do |namedoc|
							if (namedoc!="") && (namedoc!=nil)
								descriptdoc = @cp_flange_database.get_descript_doc("Документ",namedoc,"Описание_документа")
								js_command = "addrow(\"#{namedoc}\",\"#{descriptdoc}\")"
								dlg.execute_script(js_command) #запоняем список базы данных
							end
						end
					end
					#Устанавливаем текущие языковые параметры
					 dlg.execute_script("document.getElementById('text_editdoclist').innerHTML=\"#{$coolpipe_langDriver["Редактирование списка документов"]}\"")
					 dlg.execute_script("document.getElementById('text_namedoc').innerHTML=\"#{$coolpipe_langDriver["Наименование документа"]}\"")
					 dlg.execute_script("document.getElementById('text_descriptdoc').innerHTML=\"#{$coolpipe_langDriver["Описание документа"]}\"")
					 dlg.execute_script("text_realdel=\"#{$coolpipe_langDriver["Действительно удалить"]}\"")
					 dlg.execute_script("document.getElementById('newdoc').value=\"#{$coolpipe_langDriver["Новый"]}\"")
					 dlg.execute_script("document.getElementById('cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
					 dlg.execute_script("document.getElementById('save').value=\"#{$coolpipe_langDriver["Сохранить"]}\"")
					 dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
				when "cancel"
					dlg.close
				when "skp:ValueChanged@changelistdocuments"
					dlg.close
				when "changelistdocuments"
					#Редактируем список с базами
					dlg.close
					if arr[1]!="0"
						for i in 1..(arr.length-1)
							arr2 = arr[i].split("=")
							@cp_flange_database.add_newdoc(base,encode_to_utf8(arr2[0]),encode_to_utf8(arr2[1]))
						end
						cp_refreshdialog(@cp_activ_selectflange_dialog,"selectflange_dialog")
					end
				when "delete"
					@cp_flange_database.delete_doc(base,encode_to_utf8(arr[1]))
					cp_refreshdialog(@cp_activ_selectflange_dialog,"selectflange_dialog")
			end
		end
		#########
		def cp_change_list_flanges(base,doc)                #Диалог редактирования списка элементов фланцев в соотв. документе
			if @cp_change_list_flanges_dialog==nil
			@cp_flange_database = CP_csv_base.new(File.join(Sketchup.find_support_file("Plugins/CoolPipe/data/flange_base.csv"))) if @cp_flange_database==nil #Загружаем базу если она не загруженна
			dlg = UI::WebDialog.new($coolpipe_langDriver["Список элементов в документе"]+doc, true,$coolpipe_langDriver["Список элементов в документе"]+doc, 930, 500, 100, 100, true);#width,height,left,top
			@cp_change_list_flanges_dialog = dlg #глобальная переменная доступа к активному диалогу
			path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/add_flange_element_dialog.html"))
			dlg.set_file(path)
			dlg.set_background_color(dlg.get_default_dialog_color)
			dlg.add_action_callback("ValueChanged") {|dialog, params|
				enc = true
				if (params==nil) or (params=="changelistflangeselements|readalt")
					enc = false if (params=="changelistflangeselements|readalt")
					params = dlg.get_element_value("Alt_CallBack")
				end
				arr=params.split("|")
				check_commands_change_list_flanges(arr,dlg,base,doc)
			}
			dlg.max_height = 500
			dlg.max_width  = 930
			dlg.min_height = 500
			dlg.min_width  = 930
			dlg.set_on_close{@cp_change_list_flanges_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
			dlg.show
			end #if @cp_change_list_pipes_du_dialog==nil
		end
		def check_commands_change_list_flanges(arr,dlg,base,doc)
			case arr[0]
				when "listdu_load_succesfull" #если окно загруженно заполняем его
					namedu = @cp_flange_database.get_row_uniq_filter2("Тип_документа",base,"Документ",doc,"Ду")
					if namedu.length>0
						namedu.each do |du|
							d1 = @cp_flange_database.get_flange_params(base,doc,du,"D1")
							d2 = @cp_flange_database.get_flange_params(base,doc,du,"D2")
							d3 = @cp_flange_database.get_flange_params(base,doc,du,"D3")
							d4 = @cp_flange_database.get_flange_params(base,doc,du,"D4")
							h1 = @cp_flange_database.get_flange_params(base,doc,du,"h1")
							h2 = @cp_flange_database.get_flange_params(base,doc,du,"h2")
							h3 = @cp_flange_database.get_flange_params(base,doc,du,"h3")
							d  = @cp_flange_database.get_flange_params(base,doc,du,"d")
							n  = @cp_flange_database.get_flange_params(base,doc,du,"n")
							namedescript = @cp_flange_database.get_flange_params(base,doc,du,"Наименование_фланца")
							if (du!="") && (du!=nil) #addrow(du,dn,st,mas,name)
								js_command = "addrow(\"#{du}\",\"#{d1}\",\"#{d2}\",\"#{d3}\",\"#{d4}\",\"#{h1}\",\"#{h2}\",\"#{h3}\",\"#{d}\",\"#{n}\",\"#{namedescript}\")"
								dlg.execute_script(js_command) #запоняем список базы данных
							end
						end
					end
					#Устанавливаем текущие языковые параметры
					dlg.execute_script("document.getElementById('text_editlistflanges').innerHTML=\"#{$coolpipe_langDriver["Редактирование списка фланцев"]}\"")
					dlg.execute_script("document.getElementById('text_DiametrUslov').innerHTML=\"#{$coolpipe_langDriver["Диаметр условный"]}\"")
					dlg.execute_script("document.getElementById('text_NameForSpec').innerHTML=\"#{$coolpipe_langDriver["Наименование для спецификации"]}\"")
					dlg.execute_script("text_realdel=\"#{$coolpipe_langDriver["Действительно удалить:"]}\"")
					dlg.execute_script("document.getElementById('newdoc').value=\"#{$coolpipe_langDriver["Новый"]}\"")
					dlg.execute_script("document.getElementById('cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
					dlg.execute_script("document.getElementById('save').value=\"#{$coolpipe_langDriver["Сохранить"]}\"")
					dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
				when "cancel"
					dlg.close
				when "changelistflangeselements"
					#Редактируем список с базами
					@cp_change_list_flanges_dialog.close
					if arr[1]!="0"
						listdu=[]
						for i in 1..arr.length-1
							listdu<<encode_to_utf8(arr[i])
						end
						@cp_flange_database.add_flanges(base,doc,listdu)
						cp_refreshdialog(@cp_activ_selectflange_dialog,"selectflange_dialog")
					end
				when "delete"
					@cp_flange_database.delete_tube(base,doc,encode_to_utf8(arr[1]))
					cp_refreshdialog(@cp_activ_selectflange_dialog,"selectflange_dialog")
			end
		end
		##################################################################################################
		#------- Спецификация
		##################################################################################################
		def cp_isconector1_2_1?(face)                         #возвращает TRUE если Face - является коннектором CoolPipe
			##########################################
			# Для совместимости версии 1.2.1
			##########################################
			rez = false
			if face.class==Sketchup::Face
				rez = true if face.get_attribute("CoolPipeComponent","Тип")=="Коннектор" #объект CoolPipe - Коннектор
			end
			rez
		end
		def cp_get_connectors_arr1_2_1(component)             #Получает все коннекторы объекта, если их нет - то возвращает nil
			##########################################
			# Для совместимости версии 1.2.1
			##########################################
			arr = []
			if (component!=nil) and (component.definition.entities[0].class==Sketchup::Group)
				component.definition.entities[0].entities.each {|ent|
					if cp_isconector1_2_1?(ent)
						arr = [] if arr==nil
						arr << ent
					end
				}
				if arr==nil
					component.definition.entities[0].entities.each {|ent|
						if ent.class==Sketchup::Group
							ent.entities.each {|ent1|
								if cp_isconector1_2_1?(ent1)
									arr = [] if arr==nil
									arr << ent1
								end
							}
						end
					}
				end
			end
			arr
		end
		def get_length_tube_1_2_1(tube,attributes)
			##########################################
			# Для совместимости версии 1.2.1
			##########################################
			length = 0
			connectors = cp_get_connectors_arr1_2_1(tube)
			if (connectors.length==2) && (attributes[:Тип]=="Труба")
				tr1 = tube.definition.entities[0].transformation #обратная трансформация группы для получения абсолютных координат
				tr2 = tube.transformation                        #обратная трансформация компонента для получения абсолютных координат
				pt1 = connectors[0].bounds.center                #получение абсолютной точки начала трубопровода
				pt1 = pt1.transform! tr1
				pt1 = pt1.transform! tr2
				pt2 = connectors[1].bounds.center                #получение абсолютной точки начала трубопровода
				pt2 = pt2.transform! tr1
				pt2 = pt2.transform! tr2
				vec = pt1 - pt2
				length = ((vec.length.to_m*100).round.to_f)/100
			end
			length
		end
		######
		def cp_get_length_tube(tube,attributes) #Метод определяет длину трубопровода
			length = 0
			connectors = Sketchup::CoolPipe::cp_get_connectors_arr(tube)
			if (connectors.length==2) && (attributes[:Тип]=="Труба")
				tr1 = tube.transformation                        #трансформация для получения текщих координат
				pt1 = connectors[0].position                     #получение текущей точки начала трубопровода
				pt1 = pt1.transform! tr1
				pt2 = connectors[1].position                     #получение текущей точки конца трубопровода
				pt2 = pt2.transform! tr1
				vec = pt1 - pt2
				length = Sketchup::CoolPipe::roundf(vec.length.to_m,5) if vec!=nil
				#puts "Участок трубы length = #{length} (#{attributes[:Имя]})"
			end
			if length==0 #Строится предположение что труба начерчена в версии 1.2.1
				length=get_length_tube_1_2_1(tube,attributes)
			end
			length
		end
		def cp_get_index_from_arr(arr,el_spec)  #Возвращает индекс элемента спецификации если такой имеется, иначе результат -1
			rez = -1
			if arr!=nil
			if arr.length>0
				for i in 0..(arr.length-1)
					if (arr[i][0]==el_spec[0])&&(arr[i][1]==el_spec[1])&&(arr[i][3]==el_spec[3])#&&(arr[i][4]==el_spec[4])
						rez = i
						break
					end
				end
			end
			end
			rez
		end
		def cp_addelement!(arr,attributes,type) #Добавляет элемент спецификации в массив arr
			#puts "Проверка #{attributes[:Тип]}=#{type} ?????"
			if attributes[:Тип]==type
				element = [attributes[:Имя],attributes[:ЕдИзм],"1",attributes[:масса],attributes[:Dнар]]
                element = [attributes[:Имя]+" L=#{attributes[:L=]} мм",attributes[:ЕдИзм],"1",attributes[:масса],attributes[:Dнар]] if attributes[:Тип]=="Труба"
				index = cp_get_index_from_arr(arr,element)
				if index>-1
					arr[index][2] = (arr[index][2].to_i+1).to_s
				else
					arr << element
				end
			end
			#puts "arr1=#{arr}" if type=="Отвод"
			arr = arr.sort #Сортировка
			arr = arr.uniq #Уникальные элементы
			#puts "arr2=#{arr}" if type=="Отвод"
			arr
		end
		def cp_get_js_spec(arr,specrownum=0)    #создает js script для заполнения диалога "спецификация"
			js = ""
			arr = arr.uniq
			if arr!=nil
				if arr.length>0
					#### Выборка всех имен элементов и их сортировка по алфавиту
					sort_names = []
					arr.each {|el|;sort_names<<el[0];}
					sort_names = sort_names.sort
					####
					arr2 = [] #Сортированный массив элементов
					sort_names.each {|name|
						arr.each {|el|
						 arr2 << el if name==el[0]
						}
					}
					arr2=arr2.uniq
					####
					arr2.each {|el|
						specrownum +=1
						js+="addrowspec(\"#{el[0]}\",\"#{el[1]}\",\"#{el[2]}\",\"#{el[3]}\",\"#{specrownum}\");"
						@specification = @specification + "#{@numspec};#{el[0]};#{el[1]};#{el[2]};#{el[3]}\n"
						@numspec = @numspec+1
					}
				end
			end
			#puts "js = #{js}"
			js
		end
		def getSpecArray(entities)#РЕКУРСИВНАЯ ФУНКЦИЯ ищет все элементы CoolPipe для спецификации
			arr = []
			entities.each {|component|
				component_class = component.class.to_s
				is_cpComponent = Sketchup::CoolPipe::cp_iscpcomponent?(component)
				case component_class
					when "Sketchup::Group" #Поиск компонентов CoolPipe в группах объектов пользователя
						if is_cpComponent
							arr << component
						else
							arr += getSpecArray(component.entities)
						end
					when "Sketchup::ComponentInstance" #Поиск компонентов CoolPipe в компонентах пользователя
						if is_cpComponent
							arr << component
						else
							arr += getSpecArray(component.definition.entities)
						end
				end
				arr.compact
			}
			arr
		end
		######
		def get_entities_for_specification #Проверка необходимости подсчета выделенной геометрии или считать все вместе
			entities = nil
			model = Sketchup.active_model
			selection = model.selection
			allentities  = model.entities
			puts "--------------------------------------------"
			puts "#{$coolpipe_langDriver["Выделенных компонентов"]} = #{selection.length}"
			puts "#{$coolpipe_langDriver["Всего объектов в модели"]} = #{allentities.length}"
			if selection.length!=0
				message = "#{$coolpipe_langDriver["Посчитать только выделенную геометрию"]}?".to_sym
				result = UI.messagebox(message, MB_YESNO)
			end
			if result == IDYES
				entities = selection
			else
				entities = allentities
			end
			entities
		end
		def layerspecelements(entities)    #Создание скрипта генерации спецификации, разделенной по слоям
			componentsandlayers = {}
			js_script_layers = ""
			all_cpComponents = getSpecArray(entities) #Получение всех элементов Coolpipe (рекурсивная функция)
			all_cpComponents.each{|component| #Создание хеша компонентов по слоям
				componentsandlayers[component.layer.name] = [] if componentsandlayers[component.layer.name]==nil
				componentsandlayers[component.layer.name] << component;
			}
			componentsandlayers.each {|layer,components|
				count = 0
				pipes =  [];elbows=  [];reducers=[]
				tees=    [];caps=    [];flanges= []
				oborudov=[];armatura=[];drugoe=[];count = 0
				any_langTypes=[$coolpipe_langDriver["Отвод"],    			 $coolpipe_langDriver["Переход"],
							   $coolpipe_langDriver["Тройник"],              $coolpipe_langDriver["Заглушка"], $coolpipe_langDriver["Фланец"],
							   $coolpipe_langDriver["Основное оборудование"],$coolpipe_langDriver["Арматура"], $coolpipe_langDriver["Другое"]];
				any_langElements=[[],[],[],[],[],[],[],[]]
                area = 0; #Площадь элементов (добавлено в версии 1.4.1(2018))
				components.each {|component|
    				attributes = Sketchup::CoolPipe::cp_getattributes(component)
    				@numspec = 1
                    area += calculateComponentArea(component,attributes) #Расчет площади окраски элементов Coolpipe (добавлено в версии 1.4.1(2018))
    				if (attributes[:Тип]=="Труба")
    					if (attributes[:Учетвштуках]=="true") and (attributes[:Заданпрямуч]=="true")
    						cp_addelement!(pipes,attributes,"Труба")
    					else
    						length = cp_get_length_tube(component,attributes)
    						attributes[:Длина]=length #Добавляем атрибут "Длина" - если component имеет тип "Труба"
    						element = [attributes[:Имя],attributes[:ЕдИзм],length.to_s,attributes[:масса],attributes[:Dнар]]
    						index = cp_get_index_from_arr(pipes,element)
    						if index>-1
    							if (length!=nil)
    								pipes[index][2] = pipes[index][2].to_f+length.to_f
    								pipes[index][2] = (((pipes[index][2]*100).to_i).to_f/100).to_s
    							end
    						else
    							pipes << element
    						end
    					end
    				end
    				cp_addelement!(elbows,attributes,"Отвод")
    				cp_addelement!(reducers,attributes,"Переход")
    				cp_addelement!(tees,attributes,"Тройник")
    				cp_addelement!(caps,attributes,"Заглушка")
    				cp_addelement!(flanges,attributes,"Фланец")
    				cp_addelement!(oborudov,attributes,"Основное оборудование")
    				cp_addelement!(armatura,attributes,"Арматура")
    				cp_addelement!(drugoe,attributes,"Другое")
    				if ("Труба")!=($coolpipe_langDriver["Труба"])
    					for i in 0..(any_langTypes.length-1)
    						cp_addelement!(any_langElements[i],attributes,any_langTypes[i])
    					end
    				end
    				count += 1
				}
				puts($coolpipe_langDriver["При анализе слоя"].gsub("\\","")+" "+layer)
				puts($coolpipe_langDriver["Количество переданных элементов в спецификацию="].gsub("\\","")+count.to_s)
				if count>0 #Создание js скрипта, далее диалог спецификации
					js_script_layers+= "addrowspec(\"#{layer}:\",\"\",\"\",\"\",0);"
					js_script_layers+= cp_get_js_spec(oborudov)
					js_script_layers+= cp_get_js_spec(armatura)
					js_script_layers+= cp_get_js_spec(pipes)
					if ("Труба")!=($coolpipe_langDriver["Труба"])
						for i in 0..(any_langTypes.length-1)
							js = cp_get_js_spec(any_langElements[i])
							js_script_layers+= js if (js!=nil) and (js!="")
						end
					end
					js_script_layers+= cp_get_js_spec(elbows)
					js_script_layers+= cp_get_js_spec(reducers)
					js_script_layers+= cp_get_js_spec(tees)
					js_script_layers+= cp_get_js_spec(caps)
					js_script_layers+= cp_get_js_spec(flanges)
					js_script_layers+= cp_get_js_spec(drugoe)
                    #--------------(добавлено в версии 1.4.1(2018))
                    areas=[];
                    #area = area.round(3) #округление до 3х знаков после запятой
                    area = Sketchup::CoolPipe::roundf(area,3)
					element = [$coolpipe_langDriver["Площадь окраски"],"м²",area.to_s,"-","-"]
                    areas << element
                    js_script_layers+= cp_get_js_spec(areas)
                    #--------------
				end
			}
			js_script_layers
		end
		def fullspecelements(entities)     #Создание скрипта генерации общей спецификации
			j = 0
			pipes =  [];elbows=  [];reducers=[]
			tees=    [];caps=    [];flanges= []
			oborudov=[];armatura=[];drugoe=[];count = 0
            area = 0; #Площадь всех элементов (добавлено в версии 1.4.1(2018))
            countConnects = 0; #Количество точек соединения всех элементов (например сварных) (добавлено в версии 1.4.1(2018))
			any_langTypes=[$coolpipe_langDriver["Отвод"],    			 $coolpipe_langDriver["Переход"],
			               $coolpipe_langDriver["Тройник"],              $coolpipe_langDriver["Заглушка"], $coolpipe_langDriver["Фланец"],
					       $coolpipe_langDriver["Основное оборудование"],$coolpipe_langDriver["Арматура"], $coolpipe_langDriver["Другое"]];
			any_langElements=[[],[],[],[],[],[],[],[]]
			@all_cpComponents = getSpecArray(entities) #Получение всех элементов Coolpipe (рекурсивная функция)
    		@all_cpComponents.each {|component|
    			attributes = Sketchup::CoolPipe::cp_getattributes(component)
    			@specification = ""
    			@numspec = 1
                area += calculateComponentArea(component,attributes) #Расчет площади окраски элементов Coolpipe (добавлено в версии 1.4.1(2018))
    			if attributes[:Тип]=="Труба"
    				if (attributes[:Учетвштуках]=="true") and (attributes[:Заданпрямуч]=="true")
    					cp_addelement!(pipes,attributes,"Труба")
    				else
    					length = cp_get_length_tube(component,attributes)
    					attributes[:Длина]=length #Добавляем атрибут "Длина" - если component имеет тип "Труба"
    					element = [attributes[:Имя],attributes[:ЕдИзм],length.to_s,attributes[:масса],attributes[:Dнар]]
    					index = cp_get_index_from_arr(pipes,element)
    					if index>-1
    						if (length!=nil)
    							pipes[index][2] = pipes[index][2].to_f+length.to_f
    							pipes[index][2] = (((pipes[index][2]*100).to_i).to_f/100).to_s
    						end
    					else
    						pipes << element
    					end
    				end
    			end
    			cp_addelement!(elbows,attributes,"Отвод")
    			cp_addelement!(reducers,attributes,"Переход")
    			cp_addelement!(tees,attributes,"Тройник")
    			cp_addelement!(caps,attributes,"Заглушка")
    			cp_addelement!(flanges,attributes,"Фланец")
    			cp_addelement!(oborudov,attributes,"Основное оборудование")
    			cp_addelement!(armatura,attributes,"Арматура")
    			cp_addelement!(drugoe,attributes,"Другое")
    			if ("Труба")!=($coolpipe_langDriver["Труба"])
    				for i in 0..(any_langTypes.length-1)
    					cp_addelement!(any_langElements[i],attributes,any_langTypes[i])
    				end
    			end
    			count += 1
			}
			puts($coolpipe_langDriver["Количество переданных элементов в спецификацию="].gsub("\\","")+count.to_s)
			js_script = ""
			if count>0 #Создание js скрипта, далее диалог спецификации
				js_script+= cp_get_js_spec(oborudov)
				js_script+= cp_get_js_spec(armatura)
				js_script+= cp_get_js_spec(pipes)
				js_script+= cp_get_js_spec(elbows)
				js_script+= cp_get_js_spec(reducers)
				js_script+= cp_get_js_spec(tees)
				js_script+= cp_get_js_spec(caps)
				js_script+= cp_get_js_spec(flanges)
				js_script+= cp_get_js_spec(drugoe)
				if ("Труба")!=($coolpipe_langDriver["Труба"])
					for i in 0..(any_langTypes.length-1)
						js = cp_get_js_spec(any_langElements[i])
						js_script+= js if (js!=nil) and (js!="")
					end
				end
                #--------------(добавлено в версии 1.4.1(2018))
                areas=[];
                area = Sketchup::CoolPipe::roundf(area,3)#.round(3) #округление до 3х знаков после запятой
                element = [$coolpipe_langDriver["Площадь окраски"],"м²",area.to_s,"-","-"]
                areas << element
                js_script+= cp_get_js_spec(areas)
                #--------------
			end
			js_script
		end
		######
		def generate_CoolPipe_specification			#Диалог спецификации
			entities = get_entities_for_specification
			js_script = fullspecelements(entities)
			js_script_layers = layerspecelements(entities)
			#вывод спецификации
			if js_script.length>0 #Создание js скрипта, далее диалог спецификации
				if @cp_specification_dialog == nil
					plugins=Sketchup.find_support_file("Plugins")
					@cp_specification_dialog=UI::WebDialog.new($coolpipe_langDriver["Спецификация элементов"], true, $coolpipe_langDriver["Спецификация элементов"],700,450,0,0,true) #width,height,left,top
					@cp_specification_dialog.set_file(File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/specification.html")))
					color = @cp_specification_dialog.get_default_dialog_color
					@cp_specification_dialog.set_background_color(color)
					@cp_specification_dialog.add_action_callback("ValueChanged") {|d,p|
    					arr=p.split("|")
    					dlg = @cp_specification_dialog
    					case arr[0]
    						when "spec_load_succesfull" #если окно загруженно заполняем его
    							#Устанавливаем текущие языковые параметры
    							dlg.execute_script("document.getElementById('text_FullSpec').innerHTML=\"#{$coolpipe_langDriver["Объединенная спецификация"]}\"")
    							dlg.execute_script("document.getElementById('text_LayerSpec').innerHTML=\"#{$coolpipe_langDriver["Спецификация по слоям"]}\"")
    							dlg.execute_script("document.getElementById('text_Number').innerHTML=\"#{$coolpipe_langDriver["№"]}\"")
    							dlg.execute_script("document.getElementById('text_Name').innerHTML=\"#{$coolpipe_langDriver["Наименование и характеристика"]}\"")
    							dlg.execute_script("document.getElementById('text_EdIzm').innerHTML=\"#{$coolpipe_langDriver["Единица измерения"]}\"")
    							dlg.execute_script("document.getElementById('text_Kolvo').innerHTML=\"#{$coolpipe_langDriver["Количество"]}\"")
    							dlg.execute_script("document.getElementById('text_Massa').innerHTML=\"#{$coolpipe_langDriver["Масса единицы"]}\"")
    							dlg.execute_script("document.getElementById('cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
    							dlg.execute_script("document.getElementById('export_csv').value=\"#{$coolpipe_langDriver["Экспорт CSV"]}\"")
                                dlg.execute_script("document.getElementById('extended_information').value=\"#{$coolpipe_langDriver["Дополнительно..."]}\"")
    							dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
    							dlg.execute_script(js_script) #заполняем спецификацию
    							dlg.execute_script("refresh_exportspec()")
    						when "cancel"
    							dlg.close
    						when "exportCSV"
    							text = dlg.get_element_value("export_spec").gsub(/<br>/,"\n")
    							begin
    								Dir.mkdir("c:/coolpipe/")
    							rescue
    								puts "Папка \"c:/coolpipe/\" существует"
    							end
    							File.open("c:/coolpipe/specification.csv", "w") do |file|
    								file.puts text
    							end
    							message = "#{$coolpipe_langDriver["Экспорт выполнен в файл:"]}\"c:/coolpipe/specification.csv\""
    							puts message
    							UI.messagebox(message,MB_OK)
    						when "changespectype"
    							case arr[1]
    								when "full"
    									#puts "полная спецификация"
    									dlg.execute_script("clearspectable()")
    									dlg.execute_script(js_script)
    								when "layer"
    									#puts "спецификация по слоям"
    									dlg.execute_script("clearspectable()")
    									dlg.execute_script(js_script_layers)
    							end
    							dlg.execute_script("refresh_exportspec()")
                            when "additionallySpecInfo" #Дополнительная информация по спецификации (добавлено в версии 1.4.1(2018))
                                generate_CoolPipe_extended_information_for_specification
    					end
					}
					@cp_specification_dialog.set_on_close{@cp_specification_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
					@cp_specification_dialog.max_height = 800
					@cp_specification_dialog.max_width  = 700
					@cp_specification_dialog.min_height = 300
					@cp_specification_dialog.min_width  = 700
					@cp_specification_dialog.show
				end
			else
				UI.messagebox($coolpipe_langDriver["Объекты CoolPipe не найдены"])
			end
		end # generate_CoolPipe_specification
		##################################################################################################
		#------- РАСЧЕТ ДОПОЛНИТЕЛЬНОЙ ИНФОРМАЦИИ ПО СПЕЦИФИКАЦИИ - (добавлено в версии 1.4.1(2018)
		##################################################################################################
		def generate_CoolPipe_extended_information_for_specification #Диалог расширенной информации по спецификации (добавлено в версии 1.4.1(2018))
			needcalculate = true
			$cp_need_threds = false
			if @all_cpComponents.length>1000
				result = UI.messagebox($coolpipe_langDriver["Количество объектов >1000, расчет может занять много времени. Готовы подождать?"], MB_YESNO)
				if result == IDYES
					needcalculate = true
					$cp_need_threds = true
				else
					needcalculate = false
				end
			end
			if needcalculate == true
				threads = []
				threads << Thread.new do
					@extended_information = get_extended_information_for_specification(@all_cpComponents)
				end
				threads << Thread.new do
					@layer_extended_information = get_layer_extended_information_for_specification(@all_cpComponents) #Разделение по слоям
				end
				threads.each do |t|
					begin
						t.join
						rescue RuntimeError => e
						puts "Failed: #{e.message}"
					end
				end
				if @cp_extended_specification_dialog == nil
					plugins=Sketchup.find_support_file("Plugins")
					@cp_extended_specification_dialog=UI::WebDialog.new($coolpipe_langDriver["Расширенная информация по спецификации"], true, $coolpipe_langDriver["Расширенная информация по спецификации"],1200,450,0,0,true) #width,height,left,top
					@cp_extended_specification_dialog.set_file(File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/extended_specification.html")))
					color = @cp_extended_specification_dialog.get_default_dialog_color
					@cp_extended_specification_dialog.set_background_color(color)
					@cp_extended_specification_dialog.add_action_callback("ValueChanged") {|d,p|
						arr=p.split("|")
						dlg = @cp_extended_specification_dialog
						case arr[0]
							when "spec_load_succesfull" #если окно загруженно заполняем его
								#Устанавливаем текущие языковые параметры
								dlg.execute_script("document.getElementById('text_FullSpec').innerHTML=\"#{$coolpipe_langDriver["Объединенная спецификация"]}\"")
								dlg.execute_script("document.getElementById('text_LayerSpec').innerHTML=\"#{$coolpipe_langDriver["Спецификация по слоям"]}\"")
								dlg.execute_script("document.getElementById('text_Number').innerHTML=\"#{$coolpipe_langDriver["№"]}\"")
								dlg.execute_script("document.getElementById('text_Name').innerHTML=\"#{$coolpipe_langDriver["Наименование и техническая характеристика"]}\"")
								dlg.execute_script("document.getElementById('text_unit').innerHTML=\"#{$coolpipe_langDriver["Единица измерения"]}\"")
								dlg.execute_script("document.getElementById('text_quantity').innerHTML=\"#{$coolpipe_langDriver["Количество"]}\"")
								dlg.execute_script("document.getElementById('text_areaUnit').innerHTML=\"#{$coolpipe_langDriver["Площадь единицы, м²"]}\"")
								dlg.execute_script("document.getElementById('text_totalArea').innerHTML=\"#{$coolpipe_langDriver["Общая площадь, м²"]}\"")
								dlg.execute_script("document.getElementById('text_volumeUnit').innerHTML=\"#{$coolpipe_langDriver["Внутренний объем единицы, м³"]}\"")
								dlg.execute_script("document.getElementById('text_totalVolume').innerHTML=\"#{$coolpipe_langDriver["Внутренний общий объем, м³"]}\"")
								dlg.execute_script("document.getElementById('text_weldedJoints').innerHTML=\"#{$coolpipe_langDriver["Количество сварных соединений, шт"]}\"")
								dlg.execute_script("document.getElementById('cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
								dlg.execute_script("document.getElementById('export_csv').value=\"#{$coolpipe_langDriver["Экспорт CSV"]}\"")
								dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
								dlg.execute_script(@extended_information) #заполняем спецификацию
								dlg.execute_script("refresh_exportspec()")
							when "cancel"
								dlg.close
							when "exportCSV"
								text = dlg.get_element_value("export_spec").gsub(/<br>/,"\n")
								begin
									Dir.mkdir("c:/coolpipe/")
								rescue
									puts "Папка \"c:/coolpipe/\" существует"
								end
								File.open("c:/coolpipe/extended_specification.csv", "w") do |file|
									file.puts text
								end
								message = "#{$coolpipe_langDriver["Экспорт выполнен в файл:"]}\"c:/coolpipe/extended_specification.csv\""
								puts message
								UI.messagebox(message,MB_OK)
							when "changespectype"
								case arr[1]
									when "full"
										#puts "полная спецификация"
										dlg.execute_script("clearspectable()")
										dlg.execute_script(@extended_information)
									when "layer"
										#puts "спецификация по слоям"
										dlg.execute_script("clearspectable()")
										dlg.execute_script(@layer_extended_information) #!!!!!!!!!!!!! Сюда нужен скрипт разделенный по слоям
								end
								dlg.execute_script("refresh_exportspec()")
							end
						}
					@cp_extended_specification_dialog.set_on_close{@cp_extended_specification_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
					@cp_extended_specification_dialog.max_height = 800
					@cp_extended_specification_dialog.max_width  = 1400
					@cp_extended_specification_dialog.min_height = 300
					@cp_extended_specification_dialog.min_width  = 700
					@cp_extended_specification_dialog.show
				end
			end
        end #generate_CoolPipe_extended_information_for_specification
		###
		def get_extended_information_for_specification(all_cpComponents) # создание скрипта дополнительной информации по спецификации -(добавлено в версии 1.4.1(2018))
            js_script =""
            firstinfo = get_elements_for_extended_information_for_specification(all_cpComponents).sort.reverse
            specrownum =0
			totalarea=0
			totalvolume = 0
            firstinfo.each {|name,info|
                specrownum +=1
				totalarea+=Sketchup::CoolPipe::roundf(info[0][3],5)#Общая площадь
				totalvolume+=Sketchup::CoolPipe::roundf(info[0][5],5)#Общий внутренний объем
                js_script +="addextendedrowspec(\"#{name}\",\"#{info[0][0]}\",\"#{Sketchup::CoolPipe::roundf(info[0][1],2)}\","+ #Количество по спецификации
				                                                             "\"#{Sketchup::CoolPipe::roundf(info[0][2],5)}\","+ #Площадь единицы
																			 "\"#{Sketchup::CoolPipe::roundf(info[0][3],5)}\","+ #Общая площадь
																			 "\"#{Sketchup::CoolPipe::roundf(info[0][4],5)}\","+ #Внутренний объем единицы
																			 "\"#{Sketchup::CoolPipe::roundf(info[0][5],5)}\","+ #Общий внутренний объем
																			 "\"#{info[0][6]}\",\"#{specrownum}\");"             #Номер строки спецификации
            }
			specrownum +=1
			totalarea = Sketchup::CoolPipe::roundf(totalarea,5).to_s
			totalvolume=Sketchup::CoolPipe::roundf(totalvolume,5).to_s
			js_script +="addextendedrowspec(\"#{$coolpipe_langDriver["Итого"]}\",\"-\",\"-\",\"-\",\"#{totalarea}\",\"-\",\"#{totalvolume}\",\"-\",\"#{specrownum}\");"
            extended_information = js_script
			extended_information
        end
		def get_layer_extended_information_for_specification(all_cpComponents)
			componentsandlayers = {}
			js_script =""
			specrownum =0
			all_cpComponents.each{|component| #Создание хеша компонентов по слоям
				componentsandlayers[component.layer.name] = [] if componentsandlayers[component.layer.name]==nil
				componentsandlayers[component.layer.name] << component;
			}
			global_totalarea=0
			global_totalvolume = 0
			componentsandlayers.each {|layer,components|
				firstinfo = get_elements_for_extended_information_for_specification(components).sort.reverse
				totalarea=0
				totalvolume = 0
				js_script+= "addextendedrowspec(\"#{layer}\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\");"
				firstinfo.each {|name,info|
					specrownum +=1
					totalarea+=Sketchup::CoolPipe::roundf(info[0][3],5)#Общая площадь
					totalvolume+=Sketchup::CoolPipe::roundf(info[0][5],5)#Общий внутренний объем
					js_script +="addextendedrowspec(\"#{name}\",\"#{info[0][0]}\",\"#{Sketchup::CoolPipe::roundf(info[0][1],2)}\","+ #Количество по спецификации
																				 "\"#{Sketchup::CoolPipe::roundf(info[0][2],5)}\","+ #Площадь единицы
																				 "\"#{Sketchup::CoolPipe::roundf(info[0][3],5)}\","+ #Общая площадь
																				 "\"#{Sketchup::CoolPipe::roundf(info[0][4],5)}\","+ #Внутренний объем единицы
																				 "\"#{Sketchup::CoolPipe::roundf(info[0][5],5)}\","+ #Общий внутренний объем
																				 "\"#{info[0][6]}\",\"#{specrownum}\");"             #Номер строки спецификации
				}
				specrownum +=1
				totalarea = Sketchup::CoolPipe::roundf(totalarea,5)
				totalvolume=Sketchup::CoolPipe::roundf(totalvolume,5)
				global_totalarea+=totalarea
				global_totalvolume+=totalvolume
				js_script +="addextendedrowspec(\"#{$coolpipe_langDriver["Итого"]}\",\"-\",\"-\",\"-\",\"#{totalarea}\",\"-\",\"#{totalvolume}\",\"-\",\"#{specrownum}\");"
			}
			specrownum +=1
			global_totalarea = Sketchup::CoolPipe::roundf(global_totalarea,5)
			global_totalvolume=Sketchup::CoolPipe::roundf(global_totalvolume,5)
			js_script +="addextendedrowspec(\"#{$coolpipe_langDriver["Всего"]}\",\"-\",\"-\",\"-\",\"#{global_totalarea}\",\"-\",\"#{global_totalvolume}\",\"-\",\"#{specrownum}\");"
			layer_extended_information = js_script
			layer_extended_information
		end
		###
		def get_elements_for_extended_information_for_specification(all_cpComponents) #Получение информации об объектах Coolpipe для расширенной спецификации -(добавлено в версии 1.4.1(2018))
            firstinfo = {} #Хэш первичной информации о всех компонентах
			weldedJoints = get_count_weldedJoints(all_cpComponents)#Получение информации о количестве сварных соединений элемента
            all_cpComponents.each {|component|
                standart = Sketchup::CoolPipe::cp_iscpstandartcomponent?(component)
                if standart #Если компонент является стандартным для CoolPipe
                    attributes = Sketchup::CoolPipe::cp_getattributes(component)
                    area = calculateComponentArea(component,attributes)#.round(3)     #Получаем площадь элемента
                    volume = calculateComponentVolume(component,attributes)#.round(3) #Получаем внутренний объем элемента
                    if firstinfo[attributes[:Имя]]==nil
						if attributes[:Тип]!="Фланец"
							if weldedJoints[attributes[:Имя]]!=nil
								element = [attributes[:ЕдИзм],1,area,area,volume,volume,weldedJoints[attributes[:Имя]][0]]
							else
								element = [attributes[:ЕдИзм],1,area,area,volume,volume,0]
							end
						else
							element = [attributes[:ЕдИзм],1,area,area,volume,volume,0]
						end
                        if attributes[:Тип]=="Труба"
                            length = cp_get_length_tube(component,attributes)
                            areaUnit = (Math::PI*(attributes[:Dнар].to_f/1000)) #Площадь одного метра трубы
                            totalArea = areaUnit*length #Суммарная площадь трубы
                            totalVolume = volume*length #Суммарный объем трубы
							#puts "weldedJoints[attributes[:Имя]][0]=#{weldedJoints[attributes[:Имя]][0]}"
							if weldedJoints[attributes[:Имя]]!=nil
								element = [$coolpipe_langDriver["п.м."],length,areaUnit,totalArea,volume,totalVolume,weldedJoints[attributes[:Имя]][0]]
							else
								element = [$coolpipe_langDriver["п.м."],length,areaUnit,totalArea,volume,totalVolume,0]
							end
                        end
                        firstinfo[attributes[:Имя]] = []
                        firstinfo[attributes[:Имя]] << element
                    else
                        element1 = firstinfo[attributes[:Имя]]
						if attributes[:Тип]!="Фланец"
							if weldedJoints[attributes[:Имя]]!=nil
								element2 = [element1[0][0],element1[0][1]+1,area,element1[0][3]+area,volume,element1[0][5]+volume,weldedJoints[attributes[:Имя]][0]]
							else
								element2 = [element1[0][0],element1[0][1]+1,area,element1[0][3]+area,volume,element1[0][5]+volume,0]
							end
						else
							element2 = [element1[0][0],element1[0][1]+1,area,element1[0][3]+area,volume,element1[0][5]+volume,0]
						end
                        if attributes[:Тип]=="Труба"
                            lengthUnit = cp_get_length_tube(component,attributes)        #Длина рассматриваемого участка
                            length = element1[0][1]+lengthUnit #Суммарный отрезок трубы
                            areaUnit = Math::PI*(attributes[:Dнар].to_f/1000) #Площадь одного метра трубы
                            totalArea = areaUnit*length                       #Суммарная площадь трубы
                            totalVolume = volume*length                       #Суммарный объем трубы
							if weldedJoints[attributes[:Имя]]!=nil
								element2=[element1[0][0],length,areaUnit,totalArea,volume,totalVolume,weldedJoints[attributes[:Имя]][0]]
							else
								element2=[element1[0][0],length,areaUnit,totalArea,volume,totalVolume,0]
							end
                        end
                        firstinfo[attributes[:Имя]] = []
                        firstinfo[attributes[:Имя]] << element2
                    end
                end
            }
            firstinfo
        end
		###### - Вспомогательные функции для расчет дополнительной информации по спецификации
		def calculateComponentArea(component,attributes) #Расчет площади окраски стандартных элементов CoolPipe (добавлено в версии 1.4.1(2018))
            s = 0
            if attributes[:Тип]=="Труба"
                dn = attributes[:Dнар].to_f
                l = cp_get_length_tube(component,attributes)
                s = Math::PI*(dn/1000)*l
            end
            if attributes[:Тип]=="Отвод"
                dn = attributes[:Dнар].to_f
                ri = attributes[:РадиусИзгиба].to_f
                ug = attributes[:УголОтвода].to_f
                ki = 380 / ug
                lc = Math::PI*dn/1000 #Длина окружности отвода
                lr = 2*Math::PI*ri/ki/1000 #Длина отвода по прямой
                s = lc * lr
            end
            if attributes[:Тип]=="Переход"
                r1 = attributes[:D1].to_f/2000
                r2 = attributes[:D2].to_f/2000
                h  = attributes[:Длина].to_f/1000
                l  = Math.sqrt(h**2 + ((r1-r2).abs)**2)
                s  = Math::PI * l * (r1+r2)
            end
            if attributes[:Тип]=="Тройник"
                d1 = attributes[:D1].to_f/1000
                d2 = attributes[:D2].to_f/1000
                l1 = attributes[:Длина].to_f/1000
                l2 = attributes[:Высота].to_f/1000
                s1 = Math::PI*d1*l1
                s2 = Math::PI*d2*l2
                s  = s1 + s2
            end
            if attributes[:Тип]=="Заглушка"
                s = attributes[:Площадь].to_f
            end
            if attributes[:Тип]=="Фланец"
                s = attributes[:Площадь].to_f
            end
            s
        end
        def calculateComponentVolume(component,attributes) #Расчет внутреннего объема стандартных элементов CoolPipe (добавлено в версии 1.4.1(2018))
            v = 0
            if attributes[:Тип]=="Труба"
                dn = attributes[:Dнар].to_f-2*attributes[:стенка].to_f
                l = cp_get_length_tube(component,attributes)
                v = Math::PI*(dn/1000)**2/4 #Объем одного метра трубы
            end
            if attributes[:Тип]=="Отвод"
                dn = attributes[:Dнар].to_f-2*attributes[:стенка].to_f
                ri = attributes[:РадиусИзгиба].to_f
                ug = attributes[:УголОтвода].to_f
                ki = 380 / ug
                fc = Math::PI*(dn/1000)**2/4 #Площадь сечения отвода
                lr = 2*Math::PI*ri/ki/1000   #Длина отвода по прямой
                v = fc * lr
            end
            if attributes[:Тип]=="Переход"
                r1 = (attributes[:D1].to_f-2*attributes[:стенка1].to_f)/2000
                r2 = (attributes[:D2].to_f-2*attributes[:стенка2].to_f)/2000
                h  = attributes[:Длина].to_f/1000
                v  = Math::PI*h*(r1**2+r1*r2+r2**2)/3
            end
            if attributes[:Тип]=="Тройник"
                d1 = (attributes[:D1].to_f-2*attributes[:стенка1].to_f)/1000
                d2 = (attributes[:D2].to_f-2*attributes[:стенка2].to_f)/1000
                l1 = attributes[:Длина].to_f/1000
                l2 = attributes[:Высота].to_f/1000
                v1 = Math::PI*d1**2*l1/4
                v2 = Math::PI*d2**2*l2/4
                v  = v1 + v2
            end
            if attributes[:Тип]=="Заглушка"
                v = 0
            end
            if attributes[:Тип]=="Фланец"
                v = 0
            end
            v
        end
		###### - Подсчет сварных соединений
		def get_count_weldedJoints(all_cpComponents)
			all_connectors = getAllConnectors(all_cpComponents)          #Собираем все точки коннекторов со всех объектов в один массив
			welded_connectors = getWeldetConnectors(all_connectors)      #Получаем массив точек из массива коннекторов которые имеют дубликаты
			hashconnectors = get_hashconnectors(welded_connectors,all_cpComponents)
			weldedJoints = checkAndGetWeldetjoints(welded_connectors,hashconnectors) #Создаем хэш со списком сварных соединений
			weldedJoints
		end
		def getAllConnectors(all_cpComponents) #Собираем все точки коннекторов со всех объектов в один массив
			all_connectors = []
			all_cpComponents.each {|component|
				pts = getPointsFromConnectors(component)
				pts.each{|pt|all_connectors << pt}
			}
			all_connectors
		end
		def getWeldetConnectors(all_connectors)
			welded_connectors=all_connectors.select{|pt| countInArray(all_connectors,pt) > 1}.uniq
			welded_connectors
		end
		def countInArray(array,element) #Возвращает количество вхождений элемента в массив
			rez = 0
			array.each{|el|
				rez+=1 if el==element
			}
			rez
		end
		def get_hashconnectors(all_connectors,all_cpComponents)
			hashconnectors = {}
			pts = {}
			all_cpComponents.each{|component|
				pt = getPointsFromConnectors(component)
				pts[component.entityID.to_s.to_sym]=pt
			}
			all_connectors.each{|connector|
				hashconnectors[connector.to_s.to_sym]=[] if hashconnectors[connector.to_s.to_sym]==nil
				all_cpComponents.each{|component|
					pts[component.entityID.to_s.to_sym].each{|pt|
						hashconnectors[connector.to_s.to_sym]<<component if (connector==pt)&&(hashconnectors[connector.to_s.to_sym].length<2)
					}
				}
			}
			hashconnectors
		end
		def checkAndGetWeldetjoints(all_connectors,hashconnectors) #Создаем хэш со списком сварных соединений
			weldedJoints = {}
			hashconnectors.each{|connector,components| #key,value
				components = components.uniq
				#puts "components=#{components}"
				if components.length==2
					component1 = components[0]
					component2 = components[1]
					comb = [component1,component2]
					numcomb = get_connection_type_number(comb)
					if numcomb==0
						comb = [component2,component1]
						numcomb = get_connection_type_number(comb)
					end
					if numcomb!=21 #21-Фланец-Фланец
						attributes1 = Sketchup::CoolPipe::cp_getattributes(comb[0])
						if weldedJoints[attributes1[:Имя]]==nil
							weldedJoints[attributes1[:Имя]] = []
							weldedJoints[attributes1[:Имя]] << 1
						else
							count = weldedJoints[attributes1[:Имя]][0]
							count+=1
							weldedJoints[attributes1[:Имя]] = []
							weldedJoints[attributes1[:Имя]] << count
						end
					end
				end
			}
			#-------
			weldedJoints
		end
		def get_connection_type_number(combination) #Получение номера типа соединения
			#Результат соответствует порядковому номеру из списка:
			# 1 - Труба - Труба     # 7  - Отвод - Отвод     # 12 - Переход - Переход   #16 - Тройник - Тройник   #19-Заглушка-Заглушка #21-Фланец-Фланец
			# 2 - Труба - Отвод     # 8  - Отвод - Переход   # 13 - Переход - Тройник   #17 - Тройник - Заглушка  #20-Заглушка-Фланец
			# 3 - Труба - Переход   # 9  - Отвод - Тройник   # 14 - Переход - Заглушка  #18 - Тройник - Фланец
			# 4 - Труба - Тройник   # 10 - Отвод - Заглушка  # 15 - Переход - Фланец
			# 5 - Труба - Заглушка  # 11 - Отвод - Фланец
			# 6 - Труба - Фланец
			rez = 0
			type1 = Sketchup::CoolPipe::cp_getattributes(combination[0])[:Тип]
			type2 = Sketchup::CoolPipe::cp_getattributes(combination[1])[:Тип]
			rez=1  if type1=="Труба"    && type2=="Труба"
			rez=2  if type1=="Труба"    && type2=="Отвод"
			rez=3  if type1=="Труба"    && type2=="Переход"
			rez=4  if type1=="Труба"    && type2=="Тройник"
			rez=5  if type1=="Труба"    && type2=="Заглушка"
			rez=6  if type1=="Труба"    && type2=="Фланец"
			rez=7  if type1=="Отвод"    && type2=="Отвод"
			rez=8  if type1=="Отвод"    && type2=="Переход"
			rez=9  if type1=="Отвод"    && type2=="Тройник"
			rez=10 if type1=="Отвод"    && type2=="Заглушка"
			rez=11 if type1=="Отвод"    && type2=="Фланец"
			rez=12 if type1=="Переход"  && type2=="Переход"
			rez=13 if type1=="Переход"  && type2=="Тройник"
			rez=14 if type1=="Переход"  && type2=="Заглушка"
			rez=15 if type1=="Переход"  && type2=="Фланец"
			rez=16 if type1=="Тройник"  && type2=="Тройник"
			rez=17 if type1=="Тройник"  && type2=="Заглушка"
			rez=18 if type1=="Тройник"  && type2=="Фланец"
			rez=19 if type1=="Заглушка" && type2=="Заглушка"
			rez=20 if type1=="Заглушка" && type2=="Фланец"
			rez=21 if type1=="Фланец"   && type2=="Фланец"
			rez
		end
		def getPointsFromConnectors(component) #Получение массива точек коннекторов
			pts = []
			connectors = Sketchup::CoolPipe::cp_get_connectors_arr(component)
			tr = component.transformation
			connectors.each {|connector|
				pts << connector.position.transform!(tr)
			}
			pts
		end
		#############################################################################################
		#############################################################################################
		def encode_to_utf8(string)        #Декодирование символов от Sahi /* http://stroyka.in/ */
			# Автор:    sahi
			# Сайт:     http://stroyka.in/
			# Дата:     3.03.2013
			# Описание ->> скрипт кодирует текст в utf-8 команда -> encode_to_utf8(string) для
			#              веб диалогов, результат от вебдиалога возвращается в кодировке ASCII-8BIT
			#              для русского языка (взамен библиотеки iconv)
			######################
			encode_utf8 = {
			   0x80 => "\xD0\x82", 0x81 => "\xD0\x83",     0x82 => "\xE2\x80\x9A",
			   0x83 => "\xD1\x93", 0x84 => "\xE2\x80\x9E", 0x85 => "\xE2\x80\xA6",
			   0x86 => "\xE2\x80\xA0", 0x87 => "\xE2\x80\xA1", 0x88 => "\xE2\x82\xAC",
			   0x89 => "\xE2\x80\xB0", 0x8A => "\xD0\x89",     0x8B => "\xE2\x80\xB9",
			   0x8C => "\xD0\x8A", 0x8D => "\xD0\x8C", 0x8E => "\xD0\x8B",
			   0x8F => "\xD0\x8F", 0x90 => "\xD1\x92", 0x91 => "\xE2\x80\x98",
			   0x92 => "\xE2\x80\x99", 0x93 => "\xE2\x80\x9C", 0x94 => "\xE2\x80\x9D",
			   0x95 => "\xE2\x80\xA2", 0x96 => "\xE2\x80\x93", 0x97 => "\xE2\x80\x94",
			   0x99 => "\xE2\x84\xA2", 0x9A => "\xD1\x99",     0x9B => "\xE2\x80\xBA",
			   0x9C => "\xD1\x9A", 0x9D => "\xD1\x9C", 0x9E => "\xD1\x9B",
			   0x9F => "\xD1\x9F", 0xA0 => "\xC2\xA0", 0xA1 => "\xD0\x8E",
			   0xA2 => "\xD1\x9E", 0xA3 => "\xD0\x88", 0xA4 => "\xC2\xA4",
			   0xA5 => "\xD2\x90", 0xA6 => "\xC2\xA6", 0xA7 => "\xC2\xA7",
			   0xA8 => "\xD0\x81", 0xA9 => "\xC2\xA9", 0xAA => "\xD0\x84",
			   0xAB => "\xC2\xAB", 0xAC => "\xC2\xAC", 0xAD => "\xC2\xAD",
			   0xAE => "\xC2\xAE", 0xAF => "\xD0\x87", 0xB0 => "\xC2\xB0",
			   0xB1 => "\xC2\xB1", 0xB2 => "\xD0\x86", 0xB3 => "\xD1\x96",
			   0xB4 => "\xD2\x91", 0xB5 => "\xC2\xB5", 0xB6 => "\xC2\xB6",
			   0xB7 => "\xC2\xB7", 0xB8 => "\xD1\x91", 0xB9 => "\xE2\x84\x96",
			   0xBA => "\xD1\x94", 0xBB => "\xC2\xBB", 0xBC => "\xD1\x98",
			   0xBD => "\xD0\x85", 0xBE => "\xD1\x95", 0xBF => "\xD1\x97",
			   0xC0 => "\xD0\x90", 0xC1 => "\xD0\x91", 0xC2 => "\xD0\x92",
			   0xC3 => "\xD0\x93", 0xC4 => "\xD0\x94", 0xC5 => "\xD0\x95",
			   0xC6 => "\xD0\x96", 0xC7 => "\xD0\x97", 0xC8 => "\xD0\x98",
			   0xC9 => "\xD0\x99", 0xCA => "\xD0\x9A", 0xCB => "\xD0\x9B",
			   0xCC => "\xD0\x9C", 0xCD => "\xD0\x9D", 0xCE => "\xD0\x9E",
			   0xCF => "\xD0\x9F", 0xD0 => "\xD0\xA0", 0xD1 => "\xD0\xA1",
			   0xD2 => "\xD0\xA2", 0xD3 => "\xD0\xA3", 0xD4 => "\xD0\xA4",
			   0xD5 => "\xD0\xA5", 0xD6 => "\xD0\xA6", 0xD7 => "\xD0\xA7",
			   0xD8 => "\xD0\xA8", 0xD9 => "\xD0\xA9", 0xDA => "\xD0\xAA",
			   0xDB => "\xD0\xAB", 0xDC => "\xD0\xAC", 0xDD => "\xD0\xAD",
			   0xDE => "\xD0\xAE", 0xDF => "\xD0\xAF", 0xE0 => "\xD0\xB0",
			   0xE1 => "\xD0\xB1", 0xE2 => "\xD0\xB2", 0xE3 => "\xD0\xB3",
			   0xE4 => "\xD0\xB4", 0xE5 => "\xD0\xB5", 0xE6 => "\xD0\xB6",
			   0xE7 => "\xD0\xB7", 0xE8 => "\xD0\xB8", 0xE9 => "\xD0\xB9",
			   0xEA => "\xD0\xBA", 0xEB => "\xD0\xBB", 0xEC => "\xD0\xBC",
			   0xED => "\xD0\xBD", 0xEE => "\xD0\xBE", 0xEF => "\xD0\xBF",
			   0xF0 => "\xD1\x80", 0xF1 => "\xD1\x81", 0xF2 => "\xD1\x82",
			   0xF3 => "\xD1\x83", 0xF4 => "\xD1\x84", 0xF5 => "\xD1\x85",
			   0xF6 => "\xD1\x86", 0xF7 => "\xD1\x87", 0xF8 => "\xD1\x88",
			   0xF9 => "\xD1\x89", 0xFA => "\xD1\x8A", 0xFB => "\xD1\x8B",
			   0xFC => "\xD1\x8C",0xFD => "\xD1\x8D", 0xFE => "\xD1\x8E",
			   0xFF => "\xD1\x8F" }
			begin
				string = string.unpack("U*").pack("U*")
			rescue 	Exception => e
					nents = []
					if string!=nil #Дополнительное условие (а то в этом месте частенько вылетает)
						string.each_byte{|stg|
						if(encode_utf8[stg])
							nents.push encode_utf8[stg]
						else
							nents.push stg.chr
						end
						}
						string = nents.to_s
					end
			 end
			return string
		end #def encode_to_utf8(string)
	end #class CoolPipeDialogs
end #module Sketchup::CoolPipe
