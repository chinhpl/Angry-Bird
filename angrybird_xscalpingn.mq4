enum I_SIG
{
    MFI,
    CCI
};

int initial_deposit      = 0;
bool long_trade          = FALSE;
bool short_trade         = FALSE;
double all_lots          = 0;
double average_price     = 0;
double bands_highest     = 0;
double bands_lowest      = 0;
double bands_mid         = 0;
double commission        = 0;
double delta             = 0;
double i_lots            = 0;
double i_takeprofit      = 0;
double last_buy_price    = 0;
double last_sell_price   = 0;
double lots_multiplier   = 0;
double rsi          = 0;
double tp_dist           = 0;
double pipstep           = 0;
double max_dev           = 0;
int error                = 0;
int i_test               = 0;
int lotdecimal           = 2;
int magic_number         = 2222;
int previous_time        = 0;
int slip                 = 1000;
string comment           = "";
string name              = "Ilan1.6";
uint time_elapsed        = 0;
uint time_start          = GetTickCount();
extern int rsi_max       = 200;
extern int rsi_min       = -100;
extern int rsi_period    = 9;
extern int rsi_slow      = 1;
extern int stddev_period = 9;
extern double exp_base   = 1.4;
extern double lots       = 0.01;
extern I_SIG indicator   = 1;

int init()
{
    if (IsTesting())
    {
        if (rsi_min > rsi_max) ExpertRemove();
        if (rsi_max > 100 && indicator != CCI) ExpertRemove();
        if (rsi_min < 0   && indicator != CCI) ExpertRemove();
        initial_deposit = AccountBalance();
    }

    if (OrdersTotal() != 0)
    {
        last_buy_price  = FindLastBuyPrice();
        last_sell_price = FindLastSellPrice();
        Update();
        NewOrdersPlaced();
    }
    return 0;
}

int deinit()
{
    time_elapsed = GetTickCount() - time_start;
    Print("Time Elapsed: " + time_elapsed);
    Print("Iterations: "   + i_test);
    return 0;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int start()
{  //--- Works only at the first tick of a new bar
    if (!IsOptimization()) Update();
    if (previous_time == Time[0]) return 0;
    previous_time = Time[0];
    double indicator_ = IndicatorSignal();
    Update();
    //---

    if (AccountProfit() >= 0 && OrdersTotal() > 0)
    {  //--- Cancels
        if (short_trade && indicator_ ==    -500) CloseThisSymbolAll();
        if (short_trade && indicator_ ==  OP_BUY) CloseThisSymbolAll();
        if (long_trade  && indicator_ ==     500) CloseThisSymbolAll();
        if (long_trade  && indicator_ == OP_SELL) CloseThisSymbolAll();
    }  //---
    
    if (OrdersTotal() == 0)
    {  //--- First
        if (indicator_ == OP_BUY)  SendBuy();
        if (indicator_ == OP_SELL) SendSell();
        return 0;
    }  //---

    //--- Proceeding Trades
    if (short_trade             &&
        indicator_   == OP_SELL &&
        bands_lowest > last_sell_price) SendSell();
        
    if (long_trade              &&
        indicator_    == OP_BUY &&
        bands_highest < last_buy_price) SendBuy();
    //---
        
    return 0;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Update()
{
    lots_multiplier = MathPow(exp_base, OrdersTotal());
    i_lots          = NormalizeDouble(lots * lots_multiplier, lotdecimal);

    if (OrdersTotal() == 0)
    {  //--- Resets
        last_buy_price  = 0;
        last_sell_price = 0;
        long_trade      = FALSE;
        short_trade     = FALSE;
    }  //---
    else
    {
        error = OrderSelect(OrdersTotal() - 1, SELECT_BY_POS, MODE_TRADES);
        if (OrderType() == OP_BUY)  long_trade  = TRUE;
        if (OrderType() == OP_SELL) short_trade = TRUE;
    }

    if (!IsOptimization())
    {  //--- OSD Debug
        int time_difference = TimeCurrent() - Time[0];
        Comment( "RSI: "  + (int) rsi +
                " Lots: " + i_lots +
                " Time: " + time_difference);
    }  //---
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdatePipstep()
{   //--- Grabs highest deviation from one day
    max_dev = 0;
    double stddev  = 0;
    for (int i = 1440 / Period(); i >= 0; i--)
    {
        stddev = iStdDev(0, 0, stddev_period, 0, MODE_SMA, PRICE_TYPICAL, i);
        if (stddev > max_dev) max_dev = NormalizeDouble(stddev, Digits);
    }
    pipstep = NormalizeDouble(max_dev / stddev, Digits);
    //---
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void NewOrdersPlaced()
{  //--- Prevents bad results showing in tester
    if (IsTesting() && error < 0)
    {
        CloseThisSymbolAll();

        while (AccountBalance() >= initial_deposit - 1)
        {
            error = OrderSend(Symbol(), OP_BUY,
                              AccountLeverage() * (AccountBalance() / Ask), Ask,
                              slip, 0, 0, name, magic_number, 0, 0);

            error = OrderSelect(OrdersTotal() - 1, SELECT_BY_POS, MODE_TRADES);
            error =
                OrderClose(OrderTicket(), OrderLots(), Bid, slip, clrMagenta);
        }

        ExpertRemove();
        return;
    } //---
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double IndicatorSignal()
{
    double rsi_mid;
    if (indicator == MFI)
    {  //--- Indicator selection
        rsi = 0;
        for (int i = 1; i <= rsi_slow; i++)
        {
            rsi += iMFI(0, 0, rsi_period, i);
        }
        rsi /= rsi_slow;
        rsi_mid = 50;
    }
    else if (indicator == CCI)
    {
        rsi = 0;
        for (i = 1; i <= rsi_slow; i++)
        {
            rsi += iCCI(0, 0, rsi_period, PRICE_TYPICAL, i);
        }
        rsi /= rsi_slow;
        rsi_mid = 0;
    }  //---

    bands_highest = iBands(0, 0, stddev_period, 2, 0, PRICE_TYPICAL, MODE_UPPER, 1);
    bands_lowest  = iBands(0, 0, stddev_period, 2, 0, PRICE_TYPICAL, MODE_LOWER, 1);

    if (rsi > rsi_max) return OP_SELL;
    if (rsi < rsi_min) return OP_BUY;
    
    if (rsi > rsi_mid) return  500;
    if (rsi < rsi_mid) return -500;
    return (-1);
}
//+------------------------------------------------------------------+
//| SUBROUTINES                                                      |
//+------------------------------------------------------------------+
void CloseThisSymbolAll()
{
    for (int trade = OrdersTotal() - 1; trade >= 0; trade--)
    {
        error = OrderSelect(trade, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
        {
            if (OrderType() == OP_BUY)
                error =
                    OrderClose(OrderTicket(), OrderLots(), Bid, slip, clrBlue);
            if (OrderType() == OP_SELL)
                error =
                    OrderClose(OrderTicket(), OrderLots(), Ask, slip, clrBlue);
        }
    }
    Update();
}

double FindLastBuyPrice()
{
    double oldorderopenprice;
    int oldticketnumber;
    int ticketnumber = 0;
    for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
    {
        error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number &&
            OrderType() == OP_BUY)
        {
            oldticketnumber = OrderTicket();
            if (oldticketnumber > ticketnumber)
            {
                oldorderopenprice = OrderOpenPrice();
                ticketnumber      = oldticketnumber;
            }
        }
    }
    return (oldorderopenprice);
}

double FindLastSellPrice()
{
    double oldorderopenprice;
    int oldticketnumber;
    int ticketnumber = 0;
    for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
    {
        error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number &&
            OrderType() == OP_SELL)
        {
            oldticketnumber = OrderTicket();
            if (oldticketnumber > ticketnumber)
            {
                oldorderopenprice = OrderOpenPrice();
                ticketnumber      = oldticketnumber;
            }
        }
    }
    return (oldorderopenprice);
}

void SendBuy()
{
    error = OrderSend(Symbol(), OP_BUY, i_lots, Ask, slip, 0, 0, name,
                      magic_number, 0, clrLimeGreen);
    last_buy_price = Ask;
    NewOrdersPlaced();
}

void SendSell()
{
    error = OrderSend(Symbol(), OP_SELL, i_lots, Bid, slip, 0, 0, name,
                      magic_number, 0, clrHotPink);
    last_sell_price = Bid;
    NewOrdersPlaced();
}
