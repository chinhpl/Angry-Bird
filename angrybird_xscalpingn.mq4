bool indicator_high      = FALSE;
bool indicator_highest   = FALSE;
bool indicator_low       = FALSE;
bool indicator_lowest    = FALSE;
bool long_trade          = FALSE;
bool short_trade         = FALSE;
double bands_highest     = 0;
double bands_lowest      = 0;
double i_lots            = 0;
double last_buy_price    = 0;
double last_sell_price   = 0;
double lots_multiplier   = 0;
double rsi               = 0;
int error                = 0;
int initial_deposit      = 0;
int iterations           = 0;
int lotdecimal           = 2;
int magic_number         = 2222;
int previous_time        = 0;
int slip                 = 100;
string name              = "Ilan1.6";
uint time_elapsed        = 0;
uint time_start          = GetTickCount();
extern int rsi_max       = 150;
extern int rsi_min       = -100;
extern int rsi_period    = 13;
extern int stddev_period = 11;
extern int rsi_slow      = 5;
extern double exp_base   = 1.4;
extern double lots       = 0.01;

int init()
{
    initial_deposit = AccountBalance();
    if (OrdersTotal() != 0)
    {
        last_buy_price  = FindLastBuyPrice();
        last_sell_price = FindLastSellPrice();
        UpdateIndicator();
        Update();
        NewOrdersPlaced();
    }
    
    ObjectCreate("bands_highest", OBJ_HLINE, 0, 0, bands_highest);
    ObjectCreate("bands_lowest",  OBJ_HLINE, 0, 0, bands_lowest);    
    return 0;
}

int deinit()
{
    time_elapsed = GetTickCount() - time_start;
    Print("Time Elapsed: " + time_elapsed);
    Print("Iterations: " + iterations);
    return 0;
}

int start()
{
    //--- Works only at the first tick of a new bar
    if (!IsOptimization()) Update();
    if (previous_time == Time[0]) return 0;
    previous_time = Time[0];
    UpdateIndicator();
    Update();
    //---

    //--- Closes orders
    if (AccountProfit() > 0 && OrdersTotal() > 0)
    {
        if (short_trade && indicator_low) CloseThisSymbolAll();
        if (long_trade && indicator_high) CloseThisSymbolAll();
    }
    //---

    //--- First
    if (OrdersTotal() == 0)
    {
        if (indicator_lowest) SendBuy();
        if (indicator_highest) SendSell();
        return 0;
    }
    //---

    //--- Proceeding Trades
    if (short_trade && indicator_highest && bands_lowest > last_sell_price)
        SendSell();
    if (long_trade && indicator_lowest && bands_highest < last_buy_price)
        SendBuy();
    //---

    return 0;
}

void Update()
{
    lots_multiplier = MathPow(exp_base, OrdersTotal());
    i_lots          = NormalizeDouble(lots * lots_multiplier, lotdecimal);
    //--- Resets
    if (OrdersTotal() == 0)
    {
        last_buy_price  = 0;
        last_sell_price = 0;
        long_trade      = FALSE;
        short_trade     = FALSE;
    }
    else
    {
        error = OrderSelect(OrdersTotal() - 1, SELECT_BY_POS, MODE_TRADES);
        if (OrderType() == OP_BUY) long_trade = TRUE;
        if (OrderType() == OP_SELL) short_trade = TRUE;
    }
    //--- OSD Debug
    if (!IsOptimization())
    {
        ObjectSet("bands_highest", OBJPROP_PRICE1, bands_highest);
        ObjectSet("bands_lowest" , OBJPROP_PRICE1, bands_lowest);
        
        int time_difference = TimeCurrent() - Time[0];
        Comment(" Lots: " + i_lots + " Time: " + time_difference);
    }
    //---
}

void UpdateIndicator()
{
    rsi = 0;
    for (int i = 1; i <= rsi_slow; i++)
    {
        iterations++;
        rsi += iCCI(0, 0, rsi_period, PRICE_TYPICAL, i);
    }
    rsi /= rsi_slow;

    double rsi_upper = (rsi_max + rsi_max + rsi_min) / 3;
    double rsi_lower = (rsi_max + rsi_min + rsi_min) / 3;
    
    int high_index = iHighest(0, 0, MODE_HIGH, stddev_period, 1);
    int low_index  = iLowest(0, 0, MODE_LOW,  stddev_period, 1);
    
    bands_highest = iHigh(0, 0, high_index);
    bands_lowest  = iLow(0, 0, low_index);
    
    if (rsi > rsi_max)   indicator_highest = TRUE;
    else                 indicator_highest = FALSE;
    if (rsi < rsi_min)   indicator_lowest  = TRUE;
    else                 indicator_lowest  = FALSE;
    if (rsi > rsi_upper) indicator_high    = TRUE;
    else                 indicator_high    = FALSE;
    if (rsi < rsi_lower) indicator_low     = TRUE;
    else                 indicator_low     = FALSE;
}
void CloseThisSymbolAll()
{
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        iterations++;
        error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
        if (OrderType() == OP_BUY)
            error = OrderClose(OrderTicket(), OrderLots(), Bid, slip, clrBlue);
        if (OrderType() == OP_SELL)
            error = OrderClose(OrderTicket(), OrderLots(), Ask, slip, clrBlue);
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
        iterations++;
        error           = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
        oldticketnumber = OrderTicket();
        if (oldticketnumber > ticketnumber)
        {
            oldorderopenprice = OrderOpenPrice();
            ticketnumber      = oldticketnumber;
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
        iterations++;
        error           = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
        oldticketnumber = OrderTicket();
        if (oldticketnumber > ticketnumber)
        {
            oldorderopenprice = OrderOpenPrice();
            ticketnumber      = oldticketnumber;
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

void NewOrdersPlaced()
{
    //--- Prevents bad results showing in tester
    if (IsTesting() && error < 0)
    {
        CloseThisSymbolAll();
        while (AccountBalance() >= initial_deposit - 1)
        {
            error = OrderSend(Symbol(), OP_BUY,
                              AccountFreeMargin() / Ask,
                              Ask, slip, 0, 0, name, magic_number, 0, 0);

            CloseThisSymbolAll();
        }
        ExpertRemove();
    }
    //---
}
