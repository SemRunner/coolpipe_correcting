##################################################################################################
# cpCSVBase 1.0
# Модуль реализующий работу с базой данных в формате CSV для нужд COOL PIPE
##################################################################################################
module Sketchup::CoolPipe
    class CP_csv_base #Класс обработки базы данных в формате CSV
        def initialize(path)
            @path_base = path                   #Путь к файлу базы данных
            @base_content = ""                  #содержимое базы данных
            @base_lines = []                    #База построчно
            @base_2D_array = []                 #двумерный массив базы данных
            @base_hash = Hash.new("CoolPipe SCV DataBase") #HASH базы данных
            @base_header_str = ""               #Строка заголовков CSV файла в формате CSV
            i = 0
            File.open(path).each do |line|
                line = line.chomp
                if (line!="") && (line!=" ") && (line!=nil)
                @base_header_str = line if i==0 #первая не пустая строка является строкой заголовком базы
                @base_content += line + "\n"
                @base_lines.push(line)
                
                elements = line.split(';')
                @base_2D_array[i]=[]
                elements.each do |element|
                    if element!=nil
                    @base_2D_array[i].push(element)
                    end
                end
                i += 1
                end
            end
        end
        def get_pathbase #Возвращает путь к файлу базы данных
            @path_base
        end
        def base_content #Возвращает содержимое файла
            @base_content
        end
        def base_lines   #Возвращает массив базы по строчно
            @base_lines
        end
        def base_2D_array #Возвращает двумерный массив базы данных
            @base_2D_array
        end
        def check_arr_for_unique(arr,element) #возвращает true если такой элемент есть в массиве
            rez = false
            if arr.length>0
            for i in 0..(arr.length-1)
                rez = true if element==arr[i]
            end
            end
            rez
        end
        def get_index_row(namerow) #Получает номер столбца таблицы где расположенны namerow (ключ)
            index = -1
            for i in 0..(@base_2D_array[0].length-1)
                if namerow==@base_2D_array[0][i]
                    index = i
                    break
                end
            end
            index
        end
        def get_row_arr(namerow) #возврщает массив элементов столбца
            index = get_index_row(namerow)
            arr = []
            for i in 1..(@base_2D_array.length-1)
                arr << @base_2D_array[i][index] if (@base_2D_array[i][index]!="") or (@base_2D_array[i][index]!=nil) or (@base_2D_array[i][index]!=" ")
            end
            arr
        end
        def get_row_uniq(namerow) #возврщает массив уникальных элементов столбца
            arr = get_row_arr(namerow)
            arr = arr.uniq
            arr
        end
        def get_row_uniq_sten(st,en,namerow) #возврщает массив уникальных элементов столбца между строками №st и №en
            arr = []
            index = get_index_row(namerow)
            for i in st..en
                arr << @base_2D_array[i][index]
            end
            arr = arr.uniq
            arr
        end
        def get_row_uniq_filter1(filter,namefilter,namerow) #возврщает массив уникальных элементов столбца c учетом фильтра
            index1 = get_index_row(filter)
            index2 = get_index_row(namerow)
            rez = []
            cols_filter = []
            for i in 1..(@base_2D_array.length-1)
                cols_filter << i if (@base_2D_array[i][index1]==namefilter)
            end
            cols_filter.each {|col|
            rez << @base_2D_array[col][index2]
            }
            rez = rez.uniq
            rez
        end
        def get_row_uniq_filter2(filter1,namefilter1,filter2,namefilter2,namerow) #возврщает массив уникальных элементов столбца c учетом 2-х фильтров
            index = get_index_row(namerow)
            ast,aen = get_st_end_index(filter1,namefilter1)
            bst,ben = get_stend_with_stend(ast,aen,filter2,namefilter2)
            rez = []
            for i in bst..ben
                rez << @base_2D_array[i][index]
            end
            rez = rez.uniq
            rez
        end
        def get_row_uniq_filter3(filter1,namefilter1,filter2,namefilter2,filter3,namefilter3,namerow) #возврщает массив уникальных элементов столбца c учетом 3-х фильтров
            index = get_index_row(namerow)
            ast,aen = get_st_end_index(filter1,namefilter1)
            bst,ben = get_stend_with_stend(ast,aen,filter2,namefilter2)
            cst,cen = get_stend_with_stend(bst,ben,filter3,namefilter3)
            rez = []
            #puts "cst="+cst.to_s+" cen="+cen.to_s
            for i in cst..cen
                #puts "@base_2D_array[#{i.to_s}][#{index.to_s}]="+@base_2D_array[i][index]
                rez << @base_2D_array[i][index]
            end
            rez = rez.uniq
            rez
        end
        def get_index_col(namerow,namecol) #Ищет номер строки где есть первое совпадение с namecol в столбце namerow
            row = get_index_row(namerow)
            rez = 0
            for i in 1..(@base_2D_array.length-1)
                if namecol==@base_2D_array[i][row]
                    rez = i
                    break
                end
            end
            rez
        end
        def get_stend_with_stend(ast,aen,namerow,namecol)
            bst = -1
            ben = -1
            row = get_index_row(namerow)
            for i in ast..aen
                if (bst==-1)&&(namecol==@base_2D_array[i][row])
                bst=i
                break
                end
            end
            for i in bst..aen
                if namecol==@base_2D_array[i][row]
                ben=i
                end
            end
            ben = bst if bst>ben
            return bst,ben
        end
        def get_st_end_index(namerow,namecol) #возвращает индексы первой и последней строки равной namecol
            st = -1
            en = -1
            row = get_index_row(namerow)
            for i in 1..(@base_2D_array.length-1)
                if (st==-1)&&(namecol==@base_2D_array[i][row])
                st=i
                break
                end
            end
            for i in st..(@base_2D_array.length-1)
                if namecol==@base_2D_array[i][row]
                en=i
                end
            end
            en = st if st>en
            return st,en
        end
        def get_descript_doc(filterdoc,namedoc,namerow) #возвращает описание документа
            rez = ""
            row_index = get_index_row(namerow)
            col_index = get_index_col(filterdoc,namedoc)
            rez = @base_2D_array[col_index][row_index]
            rez
        end
        def get_descript_element(filter1,name1,filter2,name2,namerow) #возвращает наименование элемента базы по двум фильтрам
            rez = ""
            start_index,end_index = get_st_end_index(filter1,name1)
            index1 = get_index_row(filter2)
            index2 = get_index_row(namerow)
            for i in start_index..end_index
                if @base_2D_array[i][index1]==name2
                    rez = @base_2D_array[i][index2]
                    break
                end
            end
            rez
        end
        def refresh_lines_from2Darr #обновлние массива строк базы из 2D массива
            @base_lines = []
            @base_2D_array.each do |arr|
                txt = ""
                arr.each do |el|
                    txt +=el+";"
                end
                txt.chomp!(";")
                txt.chomp!
                @base_lines.push(txt) if (txt!=nil) && (txt!="") && (txt!=" ")
            end
            @base_content = ""
            for i in 0..@base_lines.length-1
                @base_content += @base_lines[i]+"\n" if i<@base_lines.length-1
                @base_content += @base_lines[i] if i==@base_lines.length-1
            end
            @base_content.chomp!
        end
        def save_base #сохранение базы и перезапуск
            File.open(get_pathbase, "w") do |file|
            file.puts @base_content
            end
            initialize(get_pathbase)
        end
        def add_newtypedoc(typedoc) #добавление нового типа документов (ГОСТ, ТУ, DIN ....)
            typedocs = get_row_uniq("Тип_документа")
            index1 = get_index_row("Тип_документа")
            index2 = get_index_row("Документ")
            index3 = get_index_row("Описание_документа")
            needadd = true
            typedocs.each do |type_doc|
                needadd = false if typedoc==type_doc
            end
            if needadd #Требуется добавить новый тип документов
                @base_2D_array[@base_2D_array.length]=[]
                @base_2D_array[@base_2D_array.length-1][index1]=typedoc
                @base_2D_array[@base_2D_array.length-1][index2]="Документ 1"
                @base_2D_array[@base_2D_array.length-1][index3]="Описание документа 1"
                refresh_lines_from2Darr 
                save_base
            end
        end
        def add_newdoc(typedoc,name_doc,descript)
            index1 = get_index_row("Тип_документа")
            index2 = get_index_row("Документ")
            index3 = get_index_row("Описание_документа")
            start_index,end_index = get_st_end_index("Тип_документа",typedoc)
            docs = get_row_uniq_sten(start_index,end_index,"Документ")
            
            check = check_arr_for_unique(docs,name_doc)
            
            put_index = end_index+1
            put_index = end_index if start_index==end_index
            put_index = end_index+1 if (start_index==end_index) && (@base_2D_array[end_index][index2]!="")
            newbase = []
            newbase[0] = @base_2D_array[0].clone #Строка заголовков столбцов
            if check==false
                j=1
                to_length = put_index if (put_index>@base_2D_array.length-1)
                to_length = @base_2D_array.length-1 if (put_index<=@base_2D_array.length-1)
                for i in 1..to_length
                    newbase[j] = @base_2D_array[i].clone if (put_index>i)
                    if (put_index==i)
                        newbase[j]=[]
                        newbase[j][index1] = typedoc
                        newbase[j][index2] = name_doc
                        newbase[j][index3] = descript
                    end
                    j+=1
                end
                if i<@base_2D_array.length-1
                for i in i..@base_2D_array.length-1
                    newbase[j] = @base_2D_array[i].clone if (@base_2D_array[i]!=nil)
                    #puts "newbase[#{j.to_s}]=#{newbase[j]}"
                    j+=1
                end
                end
                @base_2D_array = newbase.clone
                refresh_lines_from2Darr 
                #puts "@base_lines=[#{@base_lines}]\r\n"
                #puts "@base_content=[#{@base_content}]"
                save_base
            end
        end
        def get_sten_filter1(base,doc) #начало и конец документа в базе (индексы)
            st=-1
            en=-1
            st1,en1 = get_st_end_index("Тип_документа",base)
            index1 = get_index_row("Тип_документа")
            index2 = get_index_row("Документ")
            for i in st1..en1
                st = i if (@base_2D_array[i][index1]==base) && (@base_2D_array[i][index2]==doc) && (st==-1)
                en = i if (@base_2D_array[i][index1]==base) && (@base_2D_array[i][index2]==doc) 
            end
            st = en if st>en
            return st,en
        end
        def add_tubes(base,doc,listdu) #добавляет новую трубу в базу
            st1,en1 = get_sten_filter1(base,doc)
            newbase = []
            newbase[0] = @base_2D_array[0].clone #Строка заголовков столбцов
            descriptdoc = get_descript_doc("Документ",doc,"Описание_документа")
            if st1>1 #если документ не в начале базы копипуем начало базы
                for i in 1..st1-1
                    newbase << @base_2D_array[i]
                end
            end
            listdu.each {|du|
            if du!="changelistpipeelements"
            du_params = du.split("=")
            elementbase = []
            elementbase << base
            elementbase << doc
            elementbase << descriptdoc
            du_params.each {|p|elementbase<<p}
            newbase << elementbase
            end
            }
            if en1<@base_2D_array.length-1 #если документ не в конце базы копипуем конец базы
                for i in en1..@base_2D_array.length-1
                    newbase << @base_2D_array[i]
                end
            end
            @base_2D_array = newbase.clone
            refresh_lines_from2Darr 
            save_base
        end
        def add_reducers(base,doc,params) #добавляет новый переход в базу
            add_tubes(base,doc,listdu)
        end
        def add_flanges(base,doc,listdu) #добавляет новую трубу в базу
            st1,en1 = get_sten_filter1(base,doc)
            newbase = []
            newbase[0] = @base_2D_array[0].clone #Строка заголовков столбцов
            descriptdoc = get_descript_doc("Документ",doc,"Описание_документа")
            if st1>1 #если документ не в начале базы копипуем начало базы
                for i in 1..st1-1
                    newbase << @base_2D_array[i]
                end
            end
            listdu.each {|du|
            if du!="changelistpipeelements"
            du_params = du.split(";")
            elementbase = []
            elementbase << base
            elementbase << doc
            elementbase << descriptdoc
            du_params.each {|p|elementbase<<p}
            newbase << elementbase
            end
            }
            if en1<@base_2D_array.length-1 #если документ не в конце базы копипуем конец базы
                for i in en1..@base_2D_array.length-1
                    newbase << @base_2D_array[i]
                end
            end
            @base_2D_array = newbase.clone
            refresh_lines_from2Darr 
            save_base
        end
        def delete_typedoc(typedoc) #Удаление типа документов
            newbase = []
            j = 1
            newbase[0] = @base_2D_array[0].clone #Строка заголовков столбцов
            for i in 1..(@base_2D_array.length-1)
                if @base_2D_array[i][0]!=typedoc
                    newbase[j] = @base_2D_array[i]
                    j+=1
                end
            end
            @base_2D_array = newbase
            refresh_lines_from2Darr
            save_base
        end
        def delete_doc(typedoc,doc)
            newbase = []
            index1 = get_index_row("Документ")
            j = 1
            newbase[0] = @base_2D_array[0].clone #Строка заголовков столбцов
            for i in 1..(@base_2D_array.length-1)
                if @base_2D_array[i][index1]!=doc
                    newbase[j] = @base_2D_array[i].clone
                    j+=1
                end
            end
            @base_2D_array = newbase.clone
            refresh_lines_from2Darr
            #puts "@base_lines=[#{@base_lines}]\r\n"
            #puts "@base_content=[#{@base_content}]"
            save_base
        end 
        def delete_tube(base,doc,du)  #удаляет строку из базы
            st1,en1 = get_sten_filter1(base,doc)
            newbase = []
            newbase[0] = @base_2D_array[0].clone #Строка заголовков столбцов
            index1 = get_index_row("Ду")
            if st1>1 #если документ не в начале базы копипуем начало базы
                for i in 1..st1-1
                    newbase << @base_2D_array[i]
                end
            end
            for i in st1..en1
                newbase << @base_2D_array[i] if @base_2D_array[i][index1]!=du
            end
            if en1<@base_2D_array.length-1 #если документ не в начале базы копипуем начало базы
                for i in en1..@base_2D_array.length-1
                    newbase << @base_2D_array[i]
                end
            end
            @base_2D_array = newbase.clone
            refresh_lines_from2Darr 
            save_base
        end
        def get_tube_params(base,doc,du,namerow) #возвращает параметры по базе труб
            st1,en1 = get_st_end_index("Тип_документа",base)
            index1 = get_index_row("Тип_документа")
            index2 = get_index_row("Документ")
            index3 = get_index_row("Ду")
            index4 = get_index_row(namerow)
            rez = ""
            for i in st1..en1
                rez = @base_2D_array[i][index4] if (@base_2D_array[i][index1]==base) && (@base_2D_array[i][index2]==doc) && (@base_2D_array[i][index3]==du)
            end
            rez
        end
        def get_reducer_params(base,doc,du1,du2,namerow) #возвращает параметры по базе труб
            st1,en1 = get_st_end_index("Тип_документа",base)
            index1 = get_index_row("Тип_документа")
            index2 = get_index_row("Документ")
            index3 = get_index_row("DN1")
            index4 = get_index_row("DN2")
            index5 = get_index_row(namerow)
            rez = ""
            for i in st1..en1
                rez = @base_2D_array[i][index5] if (@base_2D_array[i][index1]==base) && (@base_2D_array[i][index2]==doc) && (@base_2D_array[i][index3]==du1)&& (@base_2D_array[i][index4]==du2)
            end
            rez
        end
        def get_tee_params(base,doc,du1,du2,namerow) #возвращает параметры по базе труб
            st1,en1 = get_st_end_index("Тип_документа",base)
            index1 = get_index_row("Тип_документа")
            index2 = get_index_row("Документ")
            index3 = get_index_row("Ду1")
            index4 = get_index_row("Ду2")
            index5 = get_index_row(namerow)
            rez = ""
            for i in st1..en1
                rez = @base_2D_array[i][index5] if (@base_2D_array[i][index1]==base) && (@base_2D_array[i][index2]==doc) && (@base_2D_array[i][index3]==du1)&& (@base_2D_array[i][index4]==du2)
            end
            rez
        end
        def get_flange_params(base,doc,du,namerow) #возвращает параметры по базе труб
            st1,en1 = get_st_end_index("Тип_документа",base)
            index1 = get_index_row("Тип_документа")
            index2 = get_index_row("Документ")
            index3 = get_index_row("Ду")
            index4 = get_index_row(namerow)
            rez = ""
            for i in st1..en1
                rez = @base_2D_array[i][index4] if (@base_2D_array[i][index1]==base) && (@base_2D_array[i][index2]==doc) && (@base_2D_array[i][index3]==du)
            end
            rez
        end
    ################################
        def get_layers_name
            names = get_row_uniq("Имя_слоя")
        end
        def get_colors_HTMLname
            colors = get_row_uniq("Цвет")
        end
        def save_layers(layers)
            newbase = []
            newbase[0] = @base_2D_array[0].clone #Строка заголовков столбцов
            layers.each {|layer|
            index1 = get_index_row("Имя_слоя")
            index2 = get_index_row("Цвет")
            elem = layer.split("=")
            newbase << elem        
            }
            @base_2D_array = newbase.clone
            refresh_lines_from2Darr 
            #puts "@base_lines=[#{@base_lines}]\r\n"
            #puts "@base_content=[#{@base_content}]"
            save_base
        end
        def get_color_bylayer(layer) #Получает цвет слоя по имени
            index1 = get_index_row("Имя_слоя")
            index2 = get_index_row("Цвет")
            colorRGB = ""
            for i in 1..@base_2D_array.length-1
                colorRGB = @base_2D_array[i][index2] if layer==@base_2D_array[i][index1]
            end
            colorRGB
        end
        def get_sketch_color(layer) #получает цвет SketchUP из слоя
            color_html = get_color_bylayer(layer) #получаем строку вида: "rgb(255,0,0)"
			#puts "color_html="+color_html
            rgb=color_html.split(",")
            r = (rgb[0].split("("))[1]
            g = rgb[1]
            b = (rgb[2].split(")"))[0]
            color_from_rgb = Sketchup::Color.new(r.to_i, g.to_i, b.to_i)
            color_from_rgb
        end
    end #class CP_csv_base
end #module Sketchup::CoolPipe