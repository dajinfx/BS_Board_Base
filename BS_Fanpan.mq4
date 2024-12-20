//+------------------------------------------------------------------+
//|                                                BS翻盘策略_01.mq4 |
//|                        Copyright 2016, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2016, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#include "BoardSet.mqh"
#include "CommonFunction.mqh"

extern string ea_n            = "fanpan";     //ea名称
extern double lots            = 0.01;         //初始lot 
extern int    lots_auto       = 0;            //是否根据账户金额自动调手数
extern string k_symb          = "";           //trade type
extern string symbol_type     = 1;            //1 为外汇品种 最小0.01手，2最小单位0.1手
extern int    Zhuijia         = 100;
extern int    od_stop_count   = 20; 
extern int    close_all_point = 15;
extern int    sl_p            = 0;
extern int    tp_p            = 0;
extern int    is_trade_once   = 1;
extern int    time_kind       = 1;            //timecurrent 1, timeLocal 2
extern int    open_th         = 0;
extern int    open_tm         = 0;
extern int    b_for_fanpan    = 10;
extern int    s_for_fanpan    = 10;
extern string trend_line      = "ine";

extern int    b_max_c         = 20;
extern int    s_max_c         = 20;
extern int    warningDay      = 0;
extern double close_pct       = 100;
extern int    StopHour        = 23;  
extern int    IsCheckDayFinishTime = 1;

datetime start_time;
int    magic                  = 886800;
double balance_basic          = 0;            //初始金额 设定总金额 1时，手动填入，否则
double balance                = 0;            //动态金额 (平仓之后的金额)

int    od_stop    = 0;
int    od_stop_st = 0;
string buy_profit_p           = 0;
string sell_profit_p          = 0;
string take_profit_p          = 0;
string buy_profit             = 0;
string sell_profit            = 0;
string take_profit            = 0;

int    ihighest               = 0; 
double ihight                 = 0;
int    ilowest                = 0; 
double ilow                   = 0;

int    buys=0,   sells=0;
int    buyStops=0, sellStops=0;
double highpri=0,lowpri=0;
int    fanpan_stop            = 0;
int    time_trigger           = 0;
double preTickAsk             = 0;
double preTickBid             = 0;

int    today = 0;
//+--------------------------------------------------------------------------+
/*
1. 213行  232行 趋势线接触的判断进行改进,解决ADR指标启动之后，0点自动开仓问题
*/                                  
//+--------------------------------------------------------------------------+
int OnInit()
  {
   MagicSeting();
   Board_Edite_1();
   Board_Edite_2();
   
   k_symb=Symbol();
   balance_basic=AccountBalance();  
   EventSetTimer(60);      
   ObjectSetString(0,"et_hour",  OBJPROP_TEXT,open_th);
   ObjectSetString(0,"et_minite",OBJPROP_TEXT,open_tm);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();   
   DeleteObject();
  }

void OnTick()
  {
   if(Bars<100)
   {
      Print("bars less than 100");
      return;
   }

   int obj_f_1=ObjectFind(0,"bs_c_panel_1");
   int obj_f_2=ObjectFind(0,"bs_c_panel_2");
   if( obj_f_1==-1 || obj_f_2==-1  ){
      Board_Edite_1(); 
      Board_Edite_2(); 
   }
   Board_Edite_1();
   Button_Set();
   
   buy_profit  = 0;
   sell_profit = 0;
   take_profit = 0;

   int td = TimeDay(TimeCurrent());
   
   if(today!=td){
      today   = td;
      highpri = Open[0] + 200*Point; lowpri = Close[0]- 200*Point;
      if(od_stop==2)od_stop==0;
   }
      
   balance=AccountBalance();
   
   if(ObjectFind(0,"bs_c_panel_1")==-1)Board_Edite_1();
   
   if(lots_auto==1){
      lots=(balance/100000)*3;
      if(lots<0.01)lots=0.01;
   }
   
   CalculateCurrentOrders();
   Profit_Point();
   
   
   CheckForClose();
   Od_Fanpan();
   if(od_stop==1)return;
   Od_Trade();
   
      
   preTickAsk = Ask;
   preTickBid = Bid;
  }

void Button_Set(){  
   if(ObjectGetInteger(0,"bt_do_once",OBJPROP_STATE)==1){
      if(is_trade_once ==0){
         is_trade_once = 1;
         ObjectSetInteger(0,"bt_do_once",OBJPROP_BGCOLOR,clrRed);
      }else{
         is_trade_once = 0;
         ObjectSetInteger(0,"bt_do_once",OBJPROP_BGCOLOR,C'236,233,216'); 
      }
      ObjectSetInteger(0,"bt_do_once",OBJPROP_STATE,false);
   }   
   if(ObjectGetInteger(0,"bt_stop_run",OBJPROP_STATE)==1){
      if(od_stop == 0){
         od_stop = 1;
         ObjectSetInteger(0,"bt_stop_run",OBJPROP_BGCOLOR,clrRed);
      }else{
         od_stop = 0;
         ObjectSetInteger(0,"bt_stop_run",OBJPROP_BGCOLOR,C'236,233,216'); 
      }
      ObjectSetInteger(0,"bt_stop_run",OBJPROP_STATE,false);
   } 
   if(ObjectGetInteger(0,"bt_stop_fanpan",OBJPROP_STATE)==1){
      if(fanpan_stop == 0){
         fanpan_stop = 1;
         ObjectSetInteger(0,"bt_stop_fanpan",OBJPROP_BGCOLOR,clrRed);
      }else{
         fanpan_stop = 0;
         ObjectSetInteger(0,"bt_stop_fanpan",OBJPROP_BGCOLOR,C'236,233,216'); 
      }
      ObjectSetInteger(0,"bt_stop_fanpan",OBJPROP_STATE,false);
   }
   
   if(ObjectGetInteger(0,"bt_close_all",OBJPROP_STATE)==1){
      CloseDeleteTradeAll(magic);
      od_stop=1;
      ObjectSetInteger(0,"bt_close_all",OBJPROP_STATE,false);
   } 
      
   if(ObjectGetInteger(0,"bt_close_buy",OBJPROP_STATE)==1){
      Close_Order(OP_BUY,magic);
      ObjectSetInteger(0,"bt_close_buy",OBJPROP_STATE,false);
   } 
   if(ObjectGetInteger(0,"bt_close_sell",OBJPROP_STATE)==1){
      Close_Order(OP_SELL,magic);
      ObjectSetInteger(0,"bt_close_sell",OBJPROP_STATE,false);
   } 
   if(ObjectGetInteger(0,"bt_delete",OBJPROP_STATE)==1){
      Delete_Order_All(magic);
      ObjectSetInteger(0,"bt_delete",OBJPROP_STATE,false);
   }
   
   /*
   if(ObjectGetInteger(0,"bt_buy_only",OBJPROP_STATE)==1){
      if(buy_only == 0){
         buy_only = 1;
         ObjectSetInteger(0,"bt_buy_only",OBJPROP_BGCOLOR,clrRed);
      }else{
         buy_only = 0;
         ObjectSetInteger(0,"bt_buy_only",OBJPROP_BGCOLOR,C'236,233,216'); 
      }
      ObjectSetInteger(0,"bt_buy_only",OBJPROP_STATE,false);
   } 
   
   if(ObjectGetInteger(0,"bt_sell_only",OBJPROP_STATE)==1){
      if(sell_only == 0){
         sell_only = 1;
         ObjectSetInteger(0,"bt_sell_only",OBJPROP_BGCOLOR,clrRed);
      }else{
         sell_only = 0;
         ObjectSetInteger(0,"bt_sell_only",OBJPROP_BGCOLOR,C'236,233,216'); 
      }
      ObjectSetInteger(0,"bt_sell_only",OBJPROP_STATE,false);
   }
   */ 
   
   if(time_trigger==1){
      int et_m = StringToInteger(ObjectGetString(0,"et_minite",OBJPROP_TEXT,""));
      if(et_m>59 || et_m<0){
         Alert("分钟错误！");
         ObjectSetString(0,"et_minite",OBJPROP_TEXT,"0");
      }else{
        open_tm = et_m;
      }
   }

   if(ObjectGetInteger(0,"bt_time_trigger",OBJPROP_STATE)==1){
      if(time_trigger == 0){
         time_trigger = 1;
         ObjectSetInteger(0,"bt_time_trigger",OBJPROP_BGCOLOR,clrRed);
      }else{
         time_trigger = 0;
         ObjectSetInteger(0,"bt_time_trigger",OBJPROP_BGCOLOR,C'236,233,216'); 
      }      
      ObjectSetInteger(0,"bt_time_trigger",OBJPROP_STATE,false);
   } 
   
         
   if(is_trade_once == 1)ObjectSetInteger(0,"bt_do_once", OBJPROP_BGCOLOR,clrRed);
   if(od_stop == 1)      ObjectSetInteger(0,"bt_stop_run",OBJPROP_BGCOLOR,clrRed);
}

//计算订单  
void CalculateCurrentOrders()
{
   buys=0;sells=0;buyStops=0; sellStops=0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true){
         if(OrderSymbol()==Symbol() && OrderMagicNumber()==magic)
         {
            if(OrderType()==OP_BUY)  buys++;
            if(OrderType()==OP_SELL) sells++;
            if(OrderType()==OP_BUYSTOP)  buyStops++;
            if(OrderType()==OP_SELLSTOP) sellStops++;
         }
      }
   }
}
  
int CheckForOpen()
{
   int already = 0; 
   int th_c = TimeHour(TimeCurrent());
   int tm_c = TimeMinute(TimeCurrent());
   int tw_c = TimeDayOfWeek(TimeCurrent());

   int th_l = TimeHour(TimeLocal());
   int tm_l = TimeMinute(TimeLocal());
   int tw_l = TimeDayOfWeek(TimeLocal()); 
     
   for(int i=ObjectsTotal()-1;i>=0;i--) 
   { 
      string name=ObjectName(i); 
      double trend_line_check = 0;
      if(ObjectType(name) == OBJ_TREND){
         trend_line_check = StringFind(name,trend_line,0);
         if(trend_line_check >-1){
            double TrendPrice_0 = ObjectGetValueByShift(name,0);
            
            if(TrendPrice_0>0){
               if(preTickAsk<TrendPrice_0 && Ask>TrendPrice_0)
               {
                     already=1;
                  }
                  if(preTickBid>TrendPrice_0 && Bid<TrendPrice_0)
                  {
                     already=2;
                  } 
               }
         } 
      }else
      if(ObjectType(name) == OBJ_HLINE){
         trend_line_check = StringFind(name,trend_line,0);
         if(trend_line_check >-1){
            
            double TrendPrice_0 = ObjectGet(name,OBJPROP_PRICE1);
            if(TrendPrice_0==0) continue;
            
            if(preTickAsk<TrendPrice_0 && Ask>TrendPrice_0)
            {
               already=1;
            }
            if(preTickBid>TrendPrice_0 && Bid<TrendPrice_0)
            {
               already=2;
            }    
         } 
      }else{
         if(time_trigger==1){
            if(time_kind==1 && (open_th>0 || tm_c>0)){
               if(th_c==open_th && tm_c>=open_tm){
                  if(Ask > highpri ) already = 1;
                  else
                  if(Bid < lowpri)   already = 2;
               }
            }else
            if(time_kind==2 && (open_th>0 || tm_c>0)){
               if(th_l==open_th && tm_c>=open_tm){
                  if(Ask > highpri ) already = 1;
                  else
                  if(Bid < lowpri)   already = 2;
               }      
            }
         }         
      }
      
      
   }  
   return already;
}

void Od_Trade(){
   if(IsCheckDayFinishTime = 1){
      int timehour = TimeHour(TimeCurrent());
      if(timehour==StopHour && (buys==0 && sells==0)){
         Print("----------------  timehour: ",timehour,"    current_time: ",TimeCurrent());
         return;
      }
   }
   
   if( CheckForOpen()>0){
      double pri; int os;
      if(CheckForOpen()==1){
         pri = Ask;
         os = Od_Send(k_symb,OP_BUY,lots,pri,0,0,ea_n,magic);
         start_time=TimeCurrent();
         DeleteLine();
      }else
      if(CheckForOpen()==2){
         pri = Bid;
         os = Od_Send(k_symb,OP_SELL,lots,pri,0,0,ea_n,magic);
         start_time=TimeCurrent();
         DeleteLine();
      }
      
      double buy_pri_stop=pri, sell_pri_stop=pri;
      
      if(os>0){
         for(int i=0; i<od_stop_count;i++){
            buy_pri_stop = buy_pri_stop+Zhuijia*Point;
            Od_Send(k_symb,OP_BUYSTOP,lots,buy_pri_stop,0,0,ea_n,magic);
         }
         for(int j=0; j<od_stop_count;j++){
            sell_pri_stop = sell_pri_stop-Zhuijia*Point;
            Od_Send(k_symb,OP_SELLSTOP,lots,sell_pri_stop,0,0,ea_n,magic);
         }
      }
   }
   
   if(buys>0 || sells>0)
   {
      int add_buystops  = b_max_c-(buys+buyStops);
      int add_sellstops = s_max_c-(sells+sellStops);
      Print("add_buystops: ",add_buystops,"  add_sellstops: ",add_sellstops);
      if(add_buystops>0)
      {
         for(int i=0; i<add_buystops;i++){
            int buy_pri_stop = Ask+Zhuijia*Point;
            Od_Send(k_symb,OP_BUYSTOP,lots,buy_pri_stop,0,0,ea_n,magic);
         } 
      }
      if(add_sellstops>0)
      {
         for(int i=0; i<add_sellstops;i++){
            int sell_pri_stop = Bid-Zhuijia*Point;
            Od_Send(k_symb,OP_SELLSTOP,lots,sell_pri_stop,0,0,ea_n,magic);
         }
      }
   }
}

void Od_Fanpan(){
   if(fanpan_stop==1)return;
   int    oTotal=OrdersTotal();
   for(int i=0; i<oTotal; i++){
      if(OrderSelect(i,SELECT_BY_POS)==true ){
         int    od_ticket = OrderTicket();
         double od_type   = OrderType();
         double od_pri    = OrderOpenPrice();
         string od_cmt    = OrderComment();
         
         if((buys>=b_for_fanpan ) && (sells>=s_for_fanpan)){
            Od_Modify();
            if(Od_Scan_fanpan(od_ticket)==0){
               if(od_type==OP_BUY && (Ask-od_pri)/Point>(Zhuijia)){
                  int  sf1 = StringFind(od_cmt,"/",0);
                  int str1 = 0;
                  if(sf1>-1){
                     str1 =StringToInteger(StringSubstr(od_cmt,sf1+1));
                  }               
                  Od_Send(k_symb,OP_SELLSTOP,lots,od_pri,sl_p,tp_p,ea_n+"-"+od_ticket+"/"+(str1+1),magic);
               }else
               if(od_type==OP_SELL && (od_pri-Bid)/Point>(Zhuijia)){
                  int  sf1 = StringFind(od_cmt,"/",0);
                  int str1 = 0;
                  if(sf1>-1){
                     str1 =StringToInteger(StringSubstr(od_cmt,sf1+1));
                  }               
                  Od_Send(k_symb,OP_BUYSTOP,lots,od_pri,sl_p,tp_p,ea_n+"-"+od_ticket+"/"+(str1+1),magic);
               }
            }
         }
      }
   }   
}

int Od_Scan_fanpan(int ticket){
   int    fanpan_order = 0;
   int    oTotal=OrdersTotal();
   for(int i=0; i<oTotal; i++){
      if(OrderSelect(i,SELECT_BY_POS)==true ){
         int    od_ticket = OrderTicket();
         double od_type   = OrderType();
         string od_cmt    = OrderComment();
         int    od_magic  = OrderMagicNumber();
         
         if(od_type==OP_BUYSTOP || od_type==OP_SELLSTOP){           
            int    sf1 =StringFind(od_cmt,"-",0);
            int    sf2 =StringFind(od_cmt,"/",0);
            if(sf1>-1 && sf2>-1){
               int str1 = StringToInteger(StringSubstr(od_cmt,sf1+1,(sf2-sf1)-1));
               if(str1==ticket){
                  fanpan_order = 1;
                  break;
               }
            }
         }
      }
   }    
   return fanpan_order;
}
 
void CheckForClose()
{
   /*
   if(StringToDouble(take_profit_p)>close_all_point){
      if(is_trade_once==1)od_stop=1;
      CloseDeleteTradeAll(magic);
      od_stop_st=0;
      
   }
   
   if(buys >=b_max_c  && sells >=s_max_c ){
      if(is_trade_once==1)od_stop=1;
      CloseDeleteTradeAll(magic);
      od_stop_st=0;
   }
   /*
   if( (StringToDouble(buy_profit)+StringToDouble(sell_profit))*(-1)> AccountBalance()*(5/100)){
      CloseTrade();
      od_stop = 2;
   }
   

   datetime currenTime = TimeCurrent();
   
   int checkYear       = TimeYear(start_time);
   int runningDay      = 0;
   
   if(checkYear>1970)
   runningDay          = TimeDay(currenTime-start_time);
   
   if(runningDay>warningDay && warningDay>0)
   {
      double accountProfit = AccountProfit();
      if(accountProfit>0){
         Print("超过安全震荡天数盈利止损,   time: ",TimeCurrent(),"   runningDay: ",runningDay);
         if(is_trade_once==1)od_stop=1;
         CloseDeleteTradeAll(magic);
         od_stop_st=0;
      }
      
      if(accountProfit<0 && MathAbs(accountProfit)>AccountBalance()*(close_pct/100))
      {
         Print("超过浮亏百分比","  time: ",TimeCurrent(),"   accountProfit: ",accountProfit,"     AccountBalance()*(close_pct/100): ",AccountBalance()*(close_pct/100));
         if(is_trade_once==1)od_stop=1;
         CloseDeleteTradeAll(magic);
         od_stop_st=0;
      }
   }
   */
}

int CloseDeleteTradeAll(int magic_no){
   int close_ok=0;
   int od_count=1;
   if(OrdersTotal()==0) return 0;

   od_count=OrdersTotal();
   
   int n =2;
   while(n){ 
      for(int i=0;i<od_count;i++)
      {
        if(OrderSelect(i,SELECT_BY_POS)==true && OrderSymbol()==k_symb)
        {
          double od_pro = OrderProfit();
          int    od_tic = OrderTicket();
          double od_lot = OrderLots();
          double od_cp  = OrderClosePrice(); 
          int    od_ty  = OrderType();
          int    od_magic = OrderMagicNumber();
          
          if( (od_ty == OP_BUY || od_ty == OP_SELL) && od_magic==magic_no){
             bool close=OrderClose(od_tic,od_lot,od_cp,3,Red);
             if(!close){
               Print(" close error: "+od_tic);
             }else{
               close_ok=1;
             }       
          }
          if( (od_ty == OP_BUYLIMIT || od_ty == OP_BUYSTOP || od_ty == OP_SELLLIMIT || od_ty == OP_SELLSTOP) && od_magic==magic_no){
             bool del=OrderDelete(od_tic);
          } 
        }
      }
      
      int od_count_1 = 0;
      for(int i=0;i<od_count;i++)
      {
        if(OrderSelect(i,SELECT_BY_POS)==true && OrderSymbol()==k_symb)
        {
            int    od_magic = OrderMagicNumber();
            int    od_ty    = OrderType();
            
            if(od_magic==magic_no){
               od_count_1++;
            }
        }
      }
      if(od_count_1 == 0) {
         n=0;
         break;
      }
      
   }
   
   datetime td;
   start_time = td;
   
   Print("    start_time: ",start_time);
   Sleep(500);
   return close_ok;
}

void Od_Modify(){
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i,SELECT_BY_POS)==true)
      {
         int    od_ty        = OrderType();
         double od_open_pri  = OrderOpenPrice();
         int    od_ticket    = OrderTicket();
         double od_sl        = OrderStopLoss();
         
         double od_sl_b      = 0;
         double od_sl_s      = 0;
         
         if(od_ty==OP_BUY){
            if( (Bid-od_open_pri)/Point>(Zhuijia-20) ){
               if(od_sl==0) {
                  od_sl_b = od_open_pri;
                  bool res=OrderModify(od_ticket,od_open_pri,od_sl_b,0,0,Blue);
                  if(res==1){
                  }
               }
            }         
         }else
         if(od_ty==OP_SELL){
            if( (od_open_pri-Ask)/Point>(Zhuijia-20) ){
               if(od_sl==0){ 
                  od_sl_s = od_open_pri;
                  bool res=OrderModify(od_ticket,od_open_pri,od_sl_s,0,0,Blue);
               }
            }         
         }
      } 
   }
}

void Profit_Point(){
   buy_profit_p  = Double_Str(Od_Profit_Point(OP_BUY)/10,2);
   sell_profit_p = Double_Str(Od_Profit_Point(OP_SELL)/10,2);
   take_profit_p = Double_Str((StringToDouble(buy_profit_p)+StringToDouble(sell_profit_p)),2);
}

void DeleteObject()
{
   int n=2;
   int obj_total=ObjectsTotal(); 
   PrintFormat("Total %d objects",obj_total); 
   
   for(int i=obj_total-1;i>=0;i--) 
   { 
      string name=ObjectName(i); 
      PrintFormat("object %d: %s",i,name); 
      ObjectDelete(name); 
   } 
}

void DeleteLine()
{
   int n=2;
   int obj_total=ObjectsTotal(); 
   PrintFormat("Total %d objects",obj_total); 
   
   for(int i=obj_total-1;i>=0;i--) 
   { 
      string name=ObjectName(i); 
      if(ObjectType(name) == OBJ_HLINE || ObjectType(name) == OBJ_TREND){
         ObjectDelete(name); 
      }
   } 
}

bool VLineCreate(long chart_ID, string name, int sub_window,datetime time,color clr,ENUM_LINE_STYLE style,int width, bool back,bool selection,bool hidden,long z_order)         
{ 
   if(!time) 
      time=TimeCurrent(); 
   ResetLastError(); 
   if(!ObjectCreate(chart_ID,name,OBJ_VLINE,sub_window,time,0)) 
     { 
      Print(__FUNCTION__, 
            ": failed to create a horizontal line! Error code = ",GetLastError()); 
      return(false); 
     } 
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr); 
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style); 
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width);  
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back); 
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection); 
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection); 
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden); 
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order); 
   return(true); 
}

void MagicSeting(){
   if(Symbol() == "AUDCADm" || Symbol() == "AUDCAD") magic = 808001;
   if(Symbol() == "AUDJPYm" || Symbol() == "AUDJPY") magic = 808002;
   if(Symbol() == "AUDNZDm" || Symbol() == "AUDNZD") magic = 808003;
   if(Symbol() == "AUDUSDm" || Symbol() == "AUDUSD") magic = 808004;
   if(Symbol() == "CHFJPYm" || Symbol() == "CHFJPY") magic = 808005;
   if(Symbol() == "EURAUDm" || Symbol() == "EURAUD") magic = 808006;
   if(Symbol() == "EURCADm" || Symbol() == "EURCAD") magic = 808007;
   if(Symbol() == "EURCHFm" || Symbol() == "EURCHF") magic = 808008;
   if(Symbol() == "EURGBPm" || Symbol() == "EURGBP") magic = 808009;
   if(Symbol() == "EURJPYm" || Symbol() == "EURJPY") magic = 808010;
   if(Symbol() == "EURUSDm" || Symbol() == "EURUSD") magic = 808011;
   if(Symbol() == "GBPCHFm" || Symbol() == "GBPCHF") magic = 808012;
   if(Symbol() == "GBPJPYm" || Symbol() == "GBPJPY") magic = 808013;
   if(Symbol() == "GBPUSDm" || Symbol() == "GBPUSD") magic = 808014;
   if(Symbol() == "NZDJPYm" || Symbol() == "NZDJPY") magic = 808015;
   if(Symbol() == "NZDUSDm" || Symbol() == "NZDUSD") magic = 808016;
   if(Symbol() == "USDCHFm" || Symbol() == "USDCHF") magic = 808017;
   if(Symbol() == "USDJPYm" || Symbol() == "USDJPY") magic = 808018;
   if(Symbol() == "USDCADm" || Symbol() == "USDCAD") magic = 808019;
   if(Symbol() == "GOLDm"   || Symbol() == "GOLD")   magic = 808020;
   if(Symbol() == "WTIm"    || Symbol() == "WTI")    magic = 808021;
   if(magic== 0) magic = 808999;
   
   if(Symbol() == "GOLD" || Symbol() == "GOLDm" || Symbol() == "WTI" || Symbol() == "WTIm")
   {
      if(lots<0.1){
         lots=0.1;
      }
   }
}