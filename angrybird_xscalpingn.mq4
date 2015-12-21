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
double rsi_open          = 0;
double rsi_close         = 0;
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
extern int stoch_max     = 80;
extern int stoch_min     = 20;
extern int stoch_period  = 5;
extern int stddev_period = 9;
extern double exp_base   = 1.4;
extern double lots       = 0.01;
extern I_SIG indicator   = 0;

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
    Update();
    double indicator_ = IndicatorSignal();
    //---

    if (OrdersTotal() == 0)
    {  //--- First
        if (indicator_ == OP_BUY)  SendBuy();
        if (indicator_ == OP_SELL) SendSell();
        return 0;
    }  //---

    if (AccountProfit() >= 0)
    {  //--- Cancels
        if (short_trade)
        {
            if (indicator_ == OP_BUY)
            {  //--- Closes sell and opens buy
                CloseThisSymbolAll();
                SendBuy();
                return 0;
            }
            if (indicator_ == -500)
            {  //--- Take
                CloseThisSymbolAll();
                return 0;
            }
        }
        if (long_trade)
        {
            if (indicator_ == OP_SELL)
            {  //--- Closes buy and opens sell
                CloseThisSymbolAll();
                SendSell();
                return 0;
            }
            if (indicator_ == 500)
            {  //--- Take
                CloseThisSymbolAll();
                return 0;
            }
        }
    }  //---

    //--- Proceeding Trades
    if (short_trade && indicator_ == OP_SELL && Bid > last_sell_price)
    {
        UpdatePipstep();
        if (Bid > last_sell_price + pipstep) SendSell();
    }
    else if (long_trade && indicator_ == OP_BUY && Ask < last_buy_price)
    {
        UpdatePipstep();
        if (Ask < last_buy_price - pipstep) SendBuy();
    }  //---
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
        UpdatePipstep();

        int time_difference = TimeCurrent() - Time[0];
        Comment("Pipstep: "  + pipstep +
                " Max Dev: " + max_dev +
                " Lots: "    + i_lots +
                " Time: "    + time_difference);
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
    double stoch = iStochastic(0, 0, stoch_period, 1, 1, MODE_SMA, 0, MODE_MAIN, 0);

    if (indicator == MFI)
    {  //--- Indicator selection
        rsi_open  = iMFI(0, 0, rsi_period, 1);
        rsi_close = iMFI(0, 0, rsi_period, 2);
    }
    else if (indicator == CCI)
    {
        rsi_open  = iCCI(0, 0, rsi_period, PRICE_TYPICAL, 1);
        rsi_close = iCCI(0, 0, rsi_period, PRICE_TYPICAL, 2);
    }  //---

    if (rsi_open > rsi_max) return OP_SELL;
    if (rsi_open < rsi_min) return OP_BUY;
    if (stoch > stoch_max) return  500;
    if (stoch < stoch_min) return -500;
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
