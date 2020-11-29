/////////////////////////////////////////////////////////////////////////////////////////////
////////////////////     Функции для "общения" со SketchUP           ////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////
function load_succesfull()            //сообщить SU что загрузка произведена
{
	document.getElementById('Base_Type').innerHTML="";
	message = 'skp:ValueChanged@load_succesfull|0';
	window.location=message;
	//fsetactivebase();
}
/////////////////////////////////////////////////////////////////////////////////////////////
function fsetactivebase()             //сообщить SU - установка активного массива базы данных труб
{
	document.getElementById('Document_Name').innerHTML="";
	du_select1=document.getElementById('Du_Select');
	if (du_select1!=null){du_select1.innerHTML="";}
	du_select2=document.getElementById('Du1_Select');
	if (du_select2!=null){du_select2.innerHTML="";}
	du_select3=document.getElementById('Du2_Select');
	if (du_select3!=null){du_select3.innerHTML="";}	
	name = document.getElementById('Name_Pipe');
	if (name!=null){name.innerHTML="";}
	name = document.getElementById('Name_Reducer');
	if (name!=null){name.innerHTML="";}	
	base = document.getElementById('Base_Type');
	cp_Base_Type = base.value;
	message = 'skp:ValueChanged@set_activ_base|'+base.value;
	window.location=message;
	fsetactivedocument();
}
/////////////////////////////////////////////////////////////////////////////////////////////
function fsetactivedocument()         //установка активного документа
{
	du_select1=document.getElementById('Du_Select');
	if (du_select1!=null){du_select1.innerHTML="";}
	du_select2=document.getElementById('Du1_Select');
	if (du_select2!=null){du_select2.innerHTML="";}
	du_select3=document.getElementById('Du2_Select');
	if (du_select3!=null){du_select3.innerHTML="";}	
	base = document.getElementById('Base_Type');
	doc  = document.getElementById('Document_Name');
	message = 'skp:ValueChanged@set_activ_document|'+base.value+"|"+doc.value;
	window.location=message;
	if (du_select3!=null){fsetactivedu1();}
	else {fsetactivedu();}
}
/////////////////////////////////////////////////////////////////////////////////////////////
function fsetactivedu()
{
	name = document.getElementById('Name_Pipe');
	if (name!=null){name.innerHTML="";}
	name = document.getElementById('Name_Reducer');
	if (name!=null){name.innerHTML="";}	
	base = document.getElementById('Base_Type');
	doc  = document.getElementById('Document_Name');	
	du_select=document.getElementById('Du_Select');
	if (du_select!=null){du = du_select.value;}
	du_select=document.getElementById('Du1_Select');
	if (du_select!=null){du = du_select.value;}
	du_select=document.getElementById('Du2_Select');
	if (du_select!=null){du = du_select.value;}	
	message = 'skp:ValueChanged@set_activ_du|'+base.value+"|"+doc.value+"|"+du;
	window.location=message;
}
function fsetactivedu1()
{
	du_select=document.getElementById('Du2_Select');
	if (du_select!=null){du_select.innerHTML="";}
	base = document.getElementById('Base_Type');
	doc  = document.getElementById('Document_Name');
	du1  = document.getElementById('Du1_Select');
	message = 'skp:ValueChanged@set_activ_du1|'+base.value+"|"+doc.value+"|"+du1.value;
	window.location=message;
	fsetactivedu2()
}
function fsetactivedu2()
{
	name = document.getElementById('Name_Reducer');
	if (name!=null){name.innerHTML="";}
	base = document.getElementById('Base_Type');
	doc  = document.getElementById('Document_Name');
	du1  = document.getElementById('Du1_Select');
	du2  = document.getElementById('Du2_Select');
	message = 'skp:ValueChanged@set_activ_du2|'+base.value+"|"+doc.value+"|"+du1.value+"|"+du2.value;
	window.location=message;
}
/////////////////////////////////////////////////////////////////////////////////////////////
function SketchUpCommand(command)
{
	var message = "";
	var message2 = "";
	switch(command) {
	///////////////////////////////////////////////
	case 'Изменить_список_баз_данных': {
	message = "skp:ValueChanged@change_list_base|0";
	break;
	}
	///////////////////////////////////////////////
	case 'Изменить_список_документов': {
	type = document.getElementById('Base_Type').value;
	message = "skp:ValueChanged@change_list_document|"+type;
	break;
	}
	///////////////////////////////////////////////
	case 'Изменить_список_диаметров': {
	base = document.getElementById("Base_Type").value;
	doc = document.getElementById("Document_Name").value;
	message = "skp:ValueChanged@change_list_pipes_du|"+base+"|"+doc;
	break;
	}
	///////////////////////////////////////////////
	case 'Изменить_список_переходов': {
	base = document.getElementById("Base_Type").value;
	doc = document.getElementById("Document_Name").value;
	du1  = document.getElementById('Du1_Select').value;
	message = "skp:ValueChanged@change_list_reducers|"+base+"|"+doc+"|"+du1;
	break;
	}
	///////////////////////////////////////////////
	case 'Изменить_список_слоев': {
	message = "skp:ValueChanged@change_list_layers|0";
	break;
	}
	///////////////////////////////////////////////
	case 'чертить': {	
	document.getElementById('Name_Pipe').innerHTML="";
	base = document.getElementById('Base_Type');
	doc  = document.getElementById('Document_Name');
	du   = document.getElementById('Du_Select');	
	putlayer= document.getElementById('idputlayers').checked;
	putmaterial=document.getElementById('idputmaterial').checked;
	layer=document.getElementById('idlayerselect');	
	message = 'skp:ValueChanged@draw_pipe|0';
	message2 =base.value+"|"+doc.value+"|"+du.value+"|"+putlayer+"|"+putmaterial+"|"+layer.value;
	break;
	}
	case 'чертить_переход':{
		base = document.getElementById('Base_Type');
		doc  = document.getElementById('Document_Name');
		du1  = document.getElementById('Du1_Select');
		du2  = document.getElementById('Du2_Select');
		message = 'skp:ValueChanged@draw_reducer|'+base.value+"|"+doc.value+"|"+du1.value+"|"+du2.value;
	break
	}
	case 'чертить_тройник':{
		base = document.getElementById('Base_Type');
		doc  = document.getElementById('Document_Name');
		du1  = document.getElementById('Du1_Select');
		du2  = document.getElementById('Du2_Select');
		message = 'skp:ValueChanged@draw_tee|'+base.value+"|"+doc.value+"|"+du1.value+"|"+du2.value;
	break
	}
	case 'чертить_фланец':{
		base = document.getElementById('Base_Type');
		doc  = document.getElementById('Document_Name');
		du  = document.getElementById('Du_Select');
		message = 'skp:ValueChanged@draw_flange|'+base.value+"|"+doc.value+"|"+du.value;
	break
	}
	///////////////////////////////////////////////
	case 'отмена': {
		message = "skp:ValueChanged@cancel|0";
	break;
	}	
	///////////////////////////////////////////////
	case 'сохранить': {
		message = "skp:ValueChanged@save|0";
	break;
	}	
	///////////////////////////////////////////////
	case 'восстановить': {
		document.getElementById('NumSegments').value="24";
		document.getElementById('elbowK').value="1.5";
		document.getElementById('elbowPlotnost').value="7.85";
		document.getElementById('vnGeomosn').checked=false;
		message = "skp:ValueChanged@restore|0";
	break;
	}	
	///////////////////////////////////////////////
	case 'тип_присоединения_перехода':{
		newconnect = document.getElementById('typeconnect1');
		if (newconnect.checked) {message = 'skp:ValueChanged@changetypeconnect|standart';}
		else {message = 'skp:ValueChanged@changetypeconnect|smalltobig';};
	break;
	}
	///////////////////////////////////////////////
	case 'тип_присоединения_тройника':{
		newconnect = document.getElementById('typeconnect1');
		if (newconnect.checked) {message = 'skp:ValueChanged@changetypeconnect|standart';}
		else {message = 'skp:ValueChanged@changetypeconnect|centerconnect';};
	break;
	}
	///////////////////////////////////////////////
	}
	///////////////////////////////////////////////
	message=message.replace(/'/,"\\'")
	document.getElementById("Alt_CallBack").value = message
	if (message2!="")
	{document.getElementById("Alt_CallBack").value = message2}
	window.location=message;
}
/////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////
function fcpvisible(id,show) // прячет или показывет объект id 
{
	if (show==true) {document.getElementById(id).style.display="";}
	else
	if (show==false) {document.getElementById(id).style.display="none";}
}
/////////////////////////////////////////////////////////////////////////////////////////////
function fcprefreshoptions(id,textsarray,valuesarray) //обновляет выпадающие списки 
{
	var selectbox = document.getElementById(id);
	selectbox.innerHTML="";
	for (i=0; i<valuesarray.length; i++)
		{
		if (valuesarray[i]!=undefined)
			{selectbox.options[selectbox.options.length] = new Option(textsarray[i],valuesarray[i]);}
		}
}
/////////////////////////////////////////////////////////////////////////////////////////////
function get_list_documents()  //Получает список наименований документов в базе установленной cp_activ_pipe_base
{
	cp_documents_list = [];
	if (cp_activ_pipe_base.length>0)
	{
		for(var i in cp_activ_pipe_base) 
		{
		cp_documents_list[i] = cp_activ_pipe_base[i][0][0]
		}
	}
}
/////////////////////////////////////////////////////////////////////////////////////////////
function get_list_du()  //Получает список условных диаметров согласно выбранной базе и документу
{
	cp_du_list = [];
	if (cp_activ_document.length>0)
	{
		for(var i=2;i<cp_activ_document.length;i++) 
		{
		cp_du_list[i] = cp_activ_document[i][0]
		}
	}
}
/////////////////////////////////////////////////////////////////////////////////////////////
function fcheckassign(elem) //Проверка и активация флажков слои
{	checked = elem.checked;
	checked_l = document.getElementById("checked_layers");
	checked_m = document.getElementById("checked_materials");
	
	check_layer = document.getElementById("idputlayers");
	check_mater = document.getElementById("idputmaterial");
	
	if (check_layer.checked==true)
	{
		fcpvisible("blocksellayers",true);
		checked_l.value = true;
		checked_m.value = true;
		if (check_mater.checked==false) {checked_m.value = false;}
	}
	
	if (check_layer.checked==false)
	{
		fcpvisible("blocksellayers",false);
		checked_l.value = false;
		checked_m.value = false;
		check_mater.checked=false;
	}
}
/////////////////////////////////////////////////////////////////////////////////////////////
// ДИАЛОГ - ГИДРАВЛИЧЕСКИЙ РАСЧЕТ ПРИ ВЫБОРЕ ТРУБОПРОВОДА
/////////////////////////////////////////////////////////////////////////////////////////////
function fcheckHydroassign(elem) //Проверка и активация флажка гидравлического расчета
{	checked_h=document.getElementById("checked_Hydravlik");
	check_hydro = document.getElementById("idHydravlik");
	if (check_hydro.checked==true)
	{
		fcpvisible("blockHydravlik",true);
		checked_h.value = true;
		recalc_hydravlick();
	}	
	if (check_hydro.checked==false)
	{
		fcpvisible("blockHydravlik",false);
		checked_h.value = false;
	}	
}
function recalc_hydravlick()
{
   calc_plotnost();
   calc_vyazkost();
   calc_rashod();
   calc_speed();
   calc_Re();
   calc_GidravlicTren();
   calc_UdelnPoteri();
}
function calc_rashod() //Расчет расхода
{
   q  = document.getElementById("ID_heatingpower").value;
   t1 = document.getElementById("ID_t1").value;
   t2 = document.getElementById("ID_t2").value;
   dt = Math.abs(t1-t2);
   td = document.getElementById("TD_rashod");
   lh = q/(1.163*dt);// кг/ч
   ls = lh*1000/3600;// кг/c
   window.glob_ls = ls; //глобальная переменная расхода л/с
   td.innerHTML = (Math.round(lh*1000)/1000)+' кг/ч | '+(Math.round(ls*1000)/1000)+' кг/с';
   return ls; //Вовращает расход кг/с
}
function calc_plotnost() //Расчет плотности воды по средней температуре
{
  var t1 = document.getElementById("ID_t1").value;
  var t2 = document.getElementById("ID_t2").value;
  var t = (parseInt(t1)+parseInt(t2))/2;  
  var k = t/parseInt(5); 
  var index_coolant = document.getElementById("Сoolant_Select").selectedIndex;
  var p=0;
  switch(index_coolant) {
	//Вода [5..190]°C
	case 0:{p=-parseFloat(0.0000000095)*Math.pow(k,6) + parseFloat(0.0000016838)*Math.pow(k,5) - parseFloat(0.0001279587)*Math.pow(k,4) 
             +parseFloat(0.0053472405)*Math.pow(k,3) - parseFloat(0.1825368380)*Math.pow(k,2) + parseFloat(0.2189476541)*k + parseFloat(999.9181645052);
			break;
			}
 	//Пропиленгликоль 25% [-10..100]°C
	case 1:{k+=3;
			p=-parseFloat(0.000007277923)*Math.pow(k,6) + parseFloat(0.000548776228)*Math.pow(k,5) - parseFloat(0.015118531654)*Math.pow(k,4)
			  +parseFloat(0.189115680987)*Math.pow(k,3) - parseFloat(1.172598452307)*Math.pow(k,2) + parseFloat(1.904788731597)*k + parseFloat(1030.898057499900);
			break;
			}
	//Пропиленгликоль 37%[-20..100]°C
	case 2:{k+=5;
			p= parseFloat(0.000000454828)*Math.pow(k,6) - parseFloat(0.000028813267)*Math.pow(k,5) + parseFloat(0.000637670964)*Math.pow(k,4) 
			 - parseFloat(0.004016969760)*Math.pow(k,3) - parseFloat(0.110806943383)*Math.pow(k,2) - parseFloat(0.609682906419)*k + parseFloat(1050.592169591220);
			break;
			}
	//Пропиленгликоль 45%[-30..100]°C
	case 3:{k+=7;
			p=-parseFloat(0.000002760157)*Math.pow(k,6) + parseFloat(0.000231593258)*Math.pow(k,5) - parseFloat(0.007125534252)*Math.pow(k,4) 
			  +parseFloat(0.098153664876)*Math.pow(k,3) - parseFloat(0.655324191554)*Math.pow(k,2) - parseFloat(0.135995519347)*k + parseFloat(1066.456743809390);
			break;
			}
	//Этиленгликоль 20%[-10..100]°C
	case 4:{k+=3;
			p= parseFloat(0.000001249375)*Math.pow(k,6) - parseFloat(0.000092962124)*Math.pow(k,5) + parseFloat(0.002513465784)*Math.pow(k,4) 
			 - parseFloat(0.028343846730)*Math.pow(k,3) + parseFloat(0.071887589525)*Math.pow(k,2) - parseFloat(1.098221731372)*k + parseFloat(1039.084146384140);
			break;
			}
	//Этиленгликоль 36%[-20..100]°C
	case 5:{k+=5;
			p= parseFloat(0.000001326940)*Math.pow(k,6) - parseFloat(0.000117519937)*Math.pow(k,5) + parseFloat(0.003925568893)*Math.pow(k,4) 
			 - parseFloat(0.059647629852)*Math.pow(k,3) + parseFloat(0.350368773565)*Math.pow(k,2) - parseFloat(2.312925145961)*k + parseFloat(1071.072186177590);
			break;
			}
	//Этиленгликоль 54%[-40..100]°C
	case 6:{k+=9;
			p= parseFloat(0.000000082100)*Math.pow(k,6) - parseFloat(0.000021137074)*Math.pow(k,5) + parseFloat(0.001310117372)*Math.pow(k,4)
			 - parseFloat(0.032203905314)*Math.pow(k,3) + parseFloat(0.299703924451)*Math.pow(k,2) - parseFloat(3.022540356033)*k + parseFloat(1110.936404401430);
			break;
			}
	}
  window.glob_plotnst = p;
  var tdplot = document.getElementById("TD_plotnost");
  tdplot.innerHTML = Math.round(p*100)/100+" кг/м³";
  return p; //возвращает плотность воды
}
function calc_vyazkost() //Расчет кинематической вязкости по средней температуре
{
  var t1 = document.getElementById("ID_t1").value;
  var t2 = document.getElementById("ID_t2").value;
  var t = (parseInt(t1)+parseInt(t2))/2;  
  var k = t/parseInt(5);
  var index_coolant = document.getElementById("Сoolant_Select").selectedIndex;
  var v=0;
  switch(index_coolant) {
	//Вода [5..190]°C
	case 0:{v=parseFloat(0.0000000000000062)*Math.pow(k,6)-parseFloat(0.0000000000008705)*Math.pow(k,5)+parseFloat(0.0000000000495477)*Math.pow(k,4) 
			 -parseFloat(0.0000000014847693)*Math.pow(k,3)+parseFloat(0.0000000257471882)*Math.pow(k,2)-parseFloat(0.0000002716021689)*k+parseFloat(0.0000017642528609);
			break;
			}
 	//Пропиленгликоль 25% [-10..100]°C
	case 1:{k+=3;
	//y = 0,0000000000011409 x6 - 0,0000000000912659 x5 + 0,0000000029300206 x4 - 0,0000000495123747 x3 + 0,0000004990094303 x2 - 0,0000032676534461 x + 0,0000127194122539
			v=parseFloat(0.0000000000011409)*Math.pow(k,6) - parseFloat(0.0000000000912659)*Math.pow(k,5) + parseFloat(0.0000000029300206)*Math.pow(k,4) 
			 -parseFloat(0.0000000495123747)*Math.pow(k,3) + parseFloat(0.0000004990094303)*Math.pow(k,2) - parseFloat(0.0000032676534461)*k + parseFloat(0.0000127194122539);
			break;
			}
	//Пропиленгликоль 37%[-20..100]°C
	case 2:{k+=5;
	//y = -0,0000000000049752 x6 + 0,0000000003717055 x5 - 0,0000000097333519 x4 + 0,0000000871880888 x3 + 0,0000004185215360 x2 - 0,0000117504119078 x + 0,0000570563193229
			v=-parseFloat(0.0000000000049752)*Math.pow(k,6) + parseFloat(0.0000000003717055)*Math.pow(k,5) - parseFloat(0.0000000097333519)*Math.pow(k,4) 
			  +parseFloat(0.0000000871880888)*Math.pow(k,3) + parseFloat(0.0000004185215360)*Math.pow(k,2) - parseFloat(0.0000117504119078)*k + parseFloat(0.0000570563193229);
			break;
			}
	//Пропиленгликоль 45%[-30..100]°C
	case 3:{k+=7;
	//y = 0,0000000000098033 x6 - 0,0000000010279594 x5 + 0,0000000436424391 x4 - 0,0000009615498866 x3 + 0,0000116835930251 x2 - 0,0000758764700715 x + 0,0002171711049069
			v= parseFloat(0.0000000000098033)*Math.pow(k,6) - parseFloat(0.0000000010279594)*Math.pow(k,5) + parseFloat(0.0000000436424391)*Math.pow(k,4) 
			 - parseFloat(0.0000009615498866)*Math.pow(k,3) + parseFloat(0.0000116835930251)*Math.pow(k,2) - parseFloat(0.0000758764700715)*k + parseFloat(0.0002171711049069);
			break;
			}
	//Этиленгликоль 20%[-10..100]°C
	case 4:{k+=3;
	//y = 0,0000000000006348 x6 - 0,0000000000523336 x5 + 0,0000000017376291 x4 - 0,0000000300880415 x3 + 0,0000002980918374 x2 - 0,0000017868929221 x + 0,0000065220037564
			v= parseFloat(0.0000000000006348)*Math.pow(k,6) - parseFloat(0.0000000000523336)*Math.pow(k,5) + parseFloat(0.0000000017376291)*Math.pow(k,4) 
			 - parseFloat(0.0000000300880415)*Math.pow(k,3) + parseFloat(0.0000002980918374)*Math.pow(k,2) - parseFloat(0.0000017868929221)*k + parseFloat(0.0000065220037564);
			break;
			}
	//Этиленгликоль 36%[-20..100]°C
	case 5:{k+=5;
	//y = -0,0000000000010922 x6 + 0,0000000000864798 x5 - 0,0000000025089065 x4 + 0,0000000298752075 x3 - 0,0000000504439114 x2 - 0,0000018237004446 x + 0,0000129393119807
			v=-parseFloat(0.0000000000010922)*Math.pow(k,6) + parseFloat(0.0000000000864798)*Math.pow(k,5) - parseFloat(0.0000000025089065)*Math.pow(k,4)
			  +parseFloat(0.0000000298752075)*Math.pow(k,3) - parseFloat(0.0000000504439114)*Math.pow(k,2) - parseFloat(0.0000018237004446)*k + parseFloat(0.0000129393119807);
			break;
			}
	//Этиленгликоль 54%[-40..100]°C
	case 6:{k+=9;
	//y = -0,0000000000011206 x6 + 0,0000000000464860 x5 + 0,0000000018442690 x4 - 0,0000001455742265 x3 + 0,0000033247086952 x2 - 0,0000334394799376 x + 0,0001328943424366
			v=-parseFloat(0.0000000000011206)*Math.pow(k,6) + parseFloat(0.0000000000464860)*Math.pow(k,5) + parseFloat(0.0000000018442690)*Math.pow(k,4)
			  -parseFloat(0.0000001455742265)*Math.pow(k,3) + parseFloat(0.0000033247086952)*Math.pow(k,2) - parseFloat(0.0000334394799376)*k + parseFloat(0.0001328943424366);
			break;
			}
	}
  var tdvyaz = document.getElementById("TD_vyazkost");
  tdvyaz.innerHTML = Math.round(v*Math.pow(10,8))/Math.pow(10,8)+" м²/с";
  window.glob_vyaz = v;
  return v; //возвращает кинематическую вязкость воды
}
function calc_speed() //Расчет скорости теплоносителя в выбраном трубопроводе
{
 var ls = parseFloat(window.glob_ls);
 var dvn = parseFloat(window.glob_dvn);
 var pl = parseFloat(window.glob_plotnst);
 var speed = 4*ls/pl/Math.PI/Math.pow((dvn/1000),2);
 var tdspeed = document.getElementById("TD_Speed");
 tdspeed.innerHTML = Math.round(speed*100)/100+" м/с";
 window.glob_speed = speed;
 return speed;
}
function calc_Re() //Расчет числа Рейнольдса
{
 var speed = parseFloat(window.glob_speed);
 var dvn = parseFloat(window.glob_dvn);
 var vyaz = parseFloat(window.glob_vyaz);
 var re = speed*dvn/vyaz/1000;
 var tdre = document.getElementById("TD_Re");
 tdre.innerHTML = Math.round(re);
 window.glob_re = re;
 return re;
}
function calc_GidravlicTren() //Расчет коэффициента гидравлического трения
{
 var dvn = parseFloat(window.glob_dvn);
 var re = parseFloat(window.glob_re);
 var ksh = parseFloat(document.getElementById("ID_ksh").value);
 var gtr = 0.11*Math.pow(ksh/dvn+68/re,0.25);
 var tdgtr=document.getElementById("TD_GidrTren");
 tdgtr.innerHTML = Math.round(gtr*10000)/10000;
 window.glob_gtr = gtr;
 return gtr;
}
function calc_UdelnPoteri() //Расчет удельных потерь давления на трение
{
 var gtr = parseFloat(window.glob_gtr); //коэффициент гидравлического трения
 var dvn = parseFloat(window.glob_dvn);
 var speed = parseFloat(window.glob_speed);
 var pl = parseFloat(window.glob_plotnst);
 var udelP=gtr/dvn*1000/2*speed*speed*pl;
 var tdudel=document.getElementById("TD_UdelPoteri");
 tdudel.innerHTML = Math.round(udelP)+" Па/м";
 window.glob_udelP = udelP;
 return udelP;
}
/////////////////////////////////////////////////////////////////////////////////////////////
// ДИАЛОГ УСТАНОВКИ ФИКСИРОВАННОГО ПРЯМОГО УЧАСТКА ТРУБОПРОВОДА
/////////////////////////////////////////////////////////////////////////////////////////////
function fcheckStraightTubing(elem) //Проверка и активация флажка установки параметров прямого участка
{	checked_h=document.getElementById("checked_StraightTubing");
	check_straight = document.getElementById("idStraightTubing");
	if (check_straight.checked==true)
	{
		fcpvisible("blockStraightTubing",true);
		checked_h.value = true;
	}	
	if (check_straight.checked==false)
	{
		fcpvisible("blockStraightTubing",false);
		checked_h.value = false;
	}	
}
function fConsideredInPieces(elem) //Проверка и активация флажка установки требования подсчета спецификации труб в штуках по прямым участкам
{	checked_Cons=document.getElementById("checked_ConsideredInPieces");
	check_straight = document.getElementById("idConsideredInPiecesCheck");
		 if (check_straight.checked==true)	{checked_Cons.value = true;}	
	else if (check_straight.checked==false)	{checked_Cons.value = false;}	
}
/////////////////////////////////////////////////////////////////////////////////////////////
// ДЛЯ ДИАЛОГА: "НАСТРОЙКИ ПЛАГИНА"
/////////////////////////////////////////////////////////////////////////////////////////////
function setings_load_succesfull()
{
	message = 'skp:ValueChanged@load_succesfull|0';
	window.location=message;
}
function fsetactivelang() //Установка активного флага в соответствии с выбранным языком
{
	img  = document.getElementById('activeflag');
	objSel = document.getElementById('LanguageSelect');	
	lang = objSel.options[objSel.selectedIndex].value
	switch(lang) {
		case 'Russian':{
			img.src = "../button_icons/lang/Russia.png";
		break
		}
		case 'English':{
			img.src = "../button_icons/lang/United-Kingdom.png";
		break
		}
		case 'French':{
			img.src = "../button_icons/lang/France.png";
		break
		}
		case 'Italian':{
			img.src = "../button_icons/lang/Italy.png";
		break
		}
		case 'Spanish':{
			img.src = "../button_icons/lang/Spain.png";
		break
		}
		case 'German':{
			img.src = "../button_icons/lang/Germany.png";
		break
		}
		case 'Chinese':{
			img.src = "../button_icons/lang/China.png";
		break
		}
	}		
	message = 'skp:ValueChanged@changelang|'+lang;
	window.location=message;
}
function fsetVnGeom()
{
 textbox = document.getElementById('vnGeom');
 checkbox = document.getElementById('vnGeomosn');
 if(checkbox.checked) {textbox.value = "checked";}
 else{textbox.value = "unchecked";}
}
function fsetVnGeomOsn()
{
 textbox = document.getElementById('vnGeom');
 checkbox = document.getElementById('vnGeomosn');
 if(textbox.value="checked") {checkbox.checked=true;}
 else{checkbox.checked=false;}
}