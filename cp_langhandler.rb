# Copyright 2013, Trimble Navigation Limited  /// М О Д И Ф И Ц И Р О В А Н О
module Sketchup::CoolPipe
class CP_LanguageHandler
  def initialize(strings_file_name)
	@strings_file_name = strings_file_name
    unless strings_file_name.is_a?(String)
      raise ArgumentError, 'must be a String'
    end
    # If a string is requested that isn't in our dictionary, return the string
    # requested unchanged.
	# Если строка просил не в нашем словаре, вернуть строку
	# Просил без изменений.
    @strings = Hash.new { |hash, key| key }
    # We use the global function here to get the file path of the caller,
    # then parse out just the path from the return value.
	# Мы используем глобальную функцию здесь, чтобы получить путь к файлу вызывающего абонента,
	# Затем разобрать только путь от возвращаемого значения.
    begin
    stack = File.join(Sketchup.find_support_file("Plugins/CoolPipe/cp_langhandler.rb")) #caller_locations(1, 1) #Изменение в связи с тем, что не работает в версиях раньше 2014
    end
    # if stack && stack.length > 0 && File.exist?(stack[0].path) #Изменение в связи с тем, что не работает в версиях раньше 2014
      # #extension_path = stack[0].path
    # else
      # extension_path = nil
	# end
    extension_path = stack
    parse(strings_file_name, extension_path)
end
  def get_active_lang #(новая процедура)
	lang = "en"
	lang_ini = File.join(Sketchup.find_support_file("Plugins/CoolPipe/Resources/lang.ini"))
	File.open(lang_ini).each {|line|
		line = line.chomp
		case line
			when "Lang=ru"
				lang = "ru"
			when "Lang=en"
				lang = "en"
			when "Lang=fr"
				lang = "fr"
			when "Lang=it"
				lang = "it"
			when "Lang=sp"
				lang = "sp"
			when "Lang=de"
				lang = "de"
			when "Lang=ch"
				lang = "ch"
			else
				lang = "ru"
		end
	}
	lang
  end
##############################################################################
  def getNameLang(line) #Возвращает наименование языка из файла настроек
	case line
		when "Lang=ru"
			lang_return = "Russian"
		when "Lang=en"
			lang_return = "English"
		when "Lang=fr"
			lang_return = "French"
		when "Lang=it"
			lang_return = "Italian"
		when "Lang=sp"
			lang_return = "Spanish"
		when "Lang=de"
			lang_return = "German"
		when "Lang=ch"
			lang_return = "Chinese"
		else
			lang_return = "Russian"
	end
	lang_return
  end
  def cp_select_and_set_lang #Диалог выбора языка (новая процедура)
     lang_ini = File.join(Sketchup.find_support_file("Plugins/CoolPipe/Resources/lang.ini"))
	 lang_active = "Russian"
	 File.open(lang_ini).each {|line|
		line = line.chomp
		lang_active = getNameLang(line)
	 }
	cp_settings_dialog(lang_active,lang_ini)  #Диалог настроек coolpipe
  end
##############################################################################
  def cp_settings_dialog(lang_active,lang_ini)  #Диалог настроек coolpipe
			if @cp_settings_dialog==nil
				dialog_ini = File.join(Sketchup.find_support_file("Plugins/CoolPipe/ini/CoolPipe.ini"))
				dlg = UI::WebDialog.new($coolpipe_langDriver["Настройки CoolPipe"], true,$coolpipe_langDriver["Настройки CoolPipe"], 500, 500, 100, 100, true);#width,height,left,top Перевести!!!
				@cp_settings_dialog = dlg #глобальная переменная доступа к активному диалогу
				path = File.join(Sketchup.find_support_file("Plugins/CoolPipe/html/setings.html"))
				dlg.set_file(path)
				dlg.set_background_color(dlg.get_default_dialog_color)
				dlg.add_action_callback("ValueChanged") {|dialog, params|
					if params==nil
						params = dlg.get_element_value("Alt_CallBack")
					end
					arr=params.split("|")
					check_commands_settings_dialog(arr,dlg,lang_active,dialog_ini,lang_ini) #Проверка и обработка комманд поступающих от диалогового окна
				} # end dlg.add_action_callback
				dlg.max_height = 600
				dlg.max_width  = 500
				dlg.min_height = 450
				dlg.min_width  = 500
				dlg.set_on_close{@cp_settings_dialog=nil} #при закрытии, уничтожаем ссылку на активный диалог
				dlg.show
			end #if @cp_activ_selectpipe_dialog==nil
			rez=false
	end #def cp_settings_dialog
	def check_commands_settings_dialog(arr,dlg,lang_active,dialog_ini,lang_ini) #Проверка и обработка комманд поступающих от диалогового окна
		case arr[0]
				when "load_succesfull" #если окно загруженно заполняем его
					File.open(dialog_ini).each do |line|
						line = line.chomp
						if (line!="") && (line!=" ") && (line!=nil)
							restore = line.split("|")
							dlg.execute_script("document.getElementById('option_#{lang_active}').selected =true")
							dlg.execute_script("fsetactivelang()")
							dlg.execute_script("document.getElementById('NumSegments').value=\"#{restore[0]}\"")
							dlg.execute_script("document.getElementById('elbowK').value=\"#{restore[1]}\"")
							dlg.execute_script("document.getElementById('elbowPlotnost').value=\"#{restore[2]}\"")							
							if restore[3]=="checked"
								dlg.execute_script("document.getElementById('vnGeomosn').checked=true;")
								dlg.execute_script("document.getElementById('vnGeom').value=\"checked\";")
							else
								dlg.execute_script("document.getElementById('vnGeomosn').checked=false;")
								dlg.execute_script("document.getElementById('vnGeom').value=\"unchecked\";")
							end
							dlg.execute_script("document.getElementById('countThreads').value=\"#{restore[4]}\"") #-- добавка версии 1.4.1(2018)
							dlg.execute_script("document.getElementById('text_copyright').innerHTML=\"#{$textcopyright}\"")
						end
					end
					settings_dialog_set_texts(dlg)
				when "changelang" #изменение языка
					case arr[1]
						 when "Russian"
							  lang = "Lang=ru"
						 when "English"
							  lang = "Lang=en"
						 when "French"
							  lang = "Lang=fr"
						 when "Italian"
							  lang = "Lang=it"
						 when "Spanish"
							  lang = "Lang=sp"
						 when "German"
							  lang = "Lang=de"
						 when "Chinese"
							  lang = "Lang=ch"
						 else
							  lang = "Lang=ru"
					end
					File.open(lang_ini, 'w'){|file| file.write lang}
					$coolpipe_langDriver = CP_LanguageHandler.new('coolpipe_lang_driver.strings') #Перезапуск языковых параметров
					settings_dialog_set_texts(dlg) #Обновление текста в диалоге
				when "save" #сохранить
					ss_segments = dlg.get_element_value("NumSegments") #Количество сегментов для построения круглой геометрии
					ss_elbowK = dlg.get_element_value("elbowK") #Коэффициент построения радиуса отвода от его диаметра
					ss_elbowPlotnost = dlg.get_element_value("elbowPlotnost") #Плотность материала для расчета массы отвода [г/см³]
					ss_vnGeom = dlg.get_element_value("vnGeom") #Строить внутреннюю геометрию CHECKBOX
					ss_countThread = dlg.get_element_value("countThreads") #количество потоков для расчетов <-- добавка версии 1.4.1(2018)
					text = "#{ss_segments}|#{ss_elbowK}|#{ss_elbowPlotnost}|#{ss_vnGeom}|#{ss_countThread}"
					File.open(dialog_ini, "w"){|file|;file.puts text;}
					#puts "Создан файл настроек с текстом #{text}"
					dlg.close
					Sketchup::CoolPipe::set_settings_coolpipe #Загрузка и установка настроек плагина
				when "cancel" #отмена
					dlg.close
		end
	end
	def settings_dialog_set_texts(dlg)
		dlg.execute_script("document.getElementById('text_lang').innerHTML=\"#{$coolpipe_langDriver["Выберите язык"]}\"")
		dlg.execute_script("document.getElementById('text_NumSegments').innerHTML=\"#{$coolpipe_langDriver["Количество сегментов для построения круглой геометрии"]}\"")
		dlg.execute_script("document.getElementById('text_elbowK').innerHTML=\"#{$coolpipe_langDriver["Коэффициент построения радиуса отвода от его диаметра"]}\"")
		dlg.execute_script("document.getElementById('text_elbowPlotnost').innerHTML=\"#{$coolpipe_langDriver["Плотность материала для расчета массы отвода [г/см³]"]}\"")
		dlg.execute_script("document.getElementById('text_vnGeom').innerHTML=\"#{$coolpipe_langDriver["Строить внутреннюю геометрию"]}\"")
		dlg.execute_script("document.getElementById('text_countThreads').innerHTML=\"#{$coolpipe_langDriver["Количество потоков для расчетов"]}\"") #-- добавка версии 1.4.1(2018)
		dlg.execute_script("document.getElementById('text_save').value=\"#{$coolpipe_langDriver["Сохранить"]}\"")
		dlg.execute_script("document.getElementById('text_cancel').value=\"#{$coolpipe_langDriver["Отмена"]}\"")
		dlg.execute_script("document.getElementById('text_restore').value=\"#{$coolpipe_langDriver["Восстановить"]}\"")
	end
##############################################################################
##############################################################################
##############################################################################
##############################################################################
  def [](key)
    # The key might be junk data, such as nil, in which case we just return
    # the value. The first draft of the Langhandler update raised an
    # argument error when the key wasn't a string, but that caused some
    # compatibility issues - particulary with Dynamic Components.
    value = @strings[key]
    #puts "value = @strings[#{key}]="+value.to_s
    # Return a copy of the string to prevent accidental modifications.
    if value.is_a?(String)
      value = value.dup
    end
	#puts "key=\"#{key}\" => value=\"#{value}\""
    return value
  end
  alias :GetString :[] # SketchUp 6
  # @param [String] file_name
  # @return [String]
  # @since SketchUp 2014
  def resource_path(file_name)
    unless file_name.is_a?(String)
      raise ArgumentError, 'must be a String'
    end
    if @language_folder
      file_path = File.join(@language_folder, file_name)
      if File.exists?(file_path)
        return file_path
      end
    end
    return ''
  end
  alias :GetResourcePath :resource_path # SketchUp 6
  # @return [String]
  # @since SketchUp 2014
  def strings
    return @strings
  end
  alias :GetStrings :strings # SketchUp 6
  private
  # @param [String] strings_file_name
  # @param [String] extension_file_path
  # @return [String, Nil]
  # @since SketchUp 2014
  def find_strings_file(strings_file_name, extension_file_path = nil)
    strings_file_path = ''
    # Check if there is local resources for this strings file.
    if extension_file_path
      # Get the filename without the path and extension.
      file_type = File.extname(extension_file_path)
      basename = File.basename(extension_file_path, file_type)
      # Now get the path to the extension's folder (same name as the extension
      # file name).
      extension_path = File.dirname(extension_file_path)
      #!!!!!!!!!!!!!!!!Исходный код Возвращает неправильный путь, обрезает только расширение у файла coolpipe_Start и добавляет /Resources
      #resource_folder_path = File.join(extension_path, basename, 'Resources')
      #resource_folder_path = File.expand_path(resource_folder_path)
      #UI.messagebox("1 resource_folder_path="+resource_folder_path.to_s)
      resource_folder_path = extension_path + "/Resources/"  # ИЗМЕНЕНО
      #UI.messagebox("2 resource_folder_path="+resource_folder_path.to_s)
      #strings_file_path = File.join(resource_folder_path, get_active_lang, strings_file_name) #Sketchup.get_locale Изменено на get_active_lang   (т.к. locale все время возвращает en-US)
      find_support_file = Sketchup.find_support_file("Plugins/CoolPipe/Resources/#{get_active_lang}/#{strings_file_name}") #Заменен поиск пути к файлу локализации
      if find_support_file!=nil
        strings_file_path = File.join(find_support_file)
      else
        find_support_file = Sketchup.find_support_file("Plugins/CoolPipe/Resources/ru/#{strings_file_name}") #Если отсутствует файл локализации выбранного языка - то используется русский (по умолчанию)
        strings_file_path = File.join(find_support_file) if find_support_file!=nil
      end
      # If the file is not there, then try the local default language folder.
      if File.exists?(strings_file_path) == false
        strings_file_path = File.join(resource_folder_path, 'en', strings_file_name)
      end
    end
    # If that doesn't exist, then try the SketchUp resources folder.
    if File.exists?(strings_file_path) == false
      strings_file_path = Sketchup.get_resource_path(strings_file_name)
    end
    if strings_file_path && File.exists?(strings_file_path)
      return strings_file_path
    else
      return nil
    end
  end
  # @param [String] strings_file_name
  # @param [String] extension_file_path
  # @return [Boolean]
  # @since SketchUp 6
  def parse(strings_file_name, extension_file_path = nil)
    strings_file = find_strings_file(strings_file_name, extension_file_path)
    if strings_file.nil?
	  puts "strings_file==nil"
      return false
    end
    # Set the language folder - this is used by GetResourcePath().
    @language_folder = File.expand_path(File.dirname(strings_file))
    #File.open(strings_file, 'r:BOM|UTF-8') { |lang_file|
    File.open(strings_file) { |lang_file|  #Изменение в связи с тем, что не работает в версиях раньше 2014
      entry_string = ''
      in_comment_block = false
      lang_file.each_line { |line|
        # Ignore simple comment lines - BIG assumption that the whole line
        # is a comment.
        if !line.include?('//')
          # Also ignore comment blocks.
          if line.include?('/*')
            in_comment_block = true
          end
          if in_comment_block
            if line.include?('*/')
              in_comment_block = false
            end
          else
            entry_string += line
          end
        end
        if entry_string.include?(';')
          # Parse the string into key and value parts.
          pattern = /\s*"(.+)"="(.+)"\s*;\s*/
          result = pattern.match(entry_string)
          if result && result.size == 3
            key = result[1]
            value = result[2]
            @strings[key] = value
          end
          #entry_string.clear
          entry_string="" #Изменение в связи с тем, что не работает в версиях раньше 2014
        end
      } # each line
    }
    return true
  end
end # class
end #module Sketchup::CoolPipe