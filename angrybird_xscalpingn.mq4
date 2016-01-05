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
    UpdateIndicator();
    Update();
    NewOrdersPlaced();
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

double GetLots()
{
    double total = 0;
    for (int i = 0; i < OrdersTotal(); i++)
    {
        error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
        total += OrderLots();
    }
    return total;
}

int start()
{
    Update();
    
    //--- Idle conditions - Costly update
    if (previous_time == Time[0]) return 0;
    previous_time = Time[0];
    
    if (OrdersTotal() > 0 && AccountProfit() <= 0)
    {
        if (long_trade  && Bid > last_buy_price ) return 0;
        if (short_trade && Ask < last_sell_price) return 0;
    }
    UpdateIndicator();
    //---
    
    //--- Closes orders
    if (AccountProfit() > 0 && OrdersTotal() > 0)
    {
        if (short_trade && indicator_low ) CloseThisSymbolAll();
        if (long_trade  && indicator_high) CloseThisSymbolAll();
    }
    //---
    
    //--- First order
    if (OrdersTotal() == 0)
    {
        if (indicator_lowest ) SendBuy();
        if (indicator_highest) SendSell();
        return 0;
    }
    //---
    
    //--- Proceeding Trades
    if (short_trade && indicator_highest && bands_lowest  > last_sell_price)
        SendSell();
    if (long_trade  && indicator_lowest  && bands_highest < last_buy_price )
        SendBuy();
    //---
    
    return 0;
}

void Update()
{
    lots_multiplier = MathPow(exp_base, OrdersTotal());
    i_lots          = NormalizeDouble(lots * lots_multiplier, lotdecimal);
    UpdateTradeStatus();
    //--- OSD Debug
    if (!IsTesting() || IsVisualMode())
    {
        UpdateIndicator();
        ObjectSet("bands_highest", OBJPROP_PRICE1, bands_highest);
        ObjectSet("bands_lowest" , OBJPROP_PRICE1, bands_lowest);
        
        int time_difference = TimeCurrent() - Time[0];
        Comment("\nLots: "      + i_lots +
                "\nShort: "     + short_trade +
                "\nLong: "      + long_trade +
                "\nLast Sell: " + last_sell_price +
                "\nLast Buy: "  + last_buy_price +
                "\nTime: "      + time_difference);
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
               //iMFI(0, 0, rsi_period, i);
    }
    rsi /= rsi_slow;
    
    int high_index = iHighest(0, 0, MODE_HIGH, stddev_period, 1);
    int low_index  = iLowest(0, 0, MODE_LOW,  stddev_period, 1);
    bands_highest  = iHigh(0, 0, high_index);
    bands_lowest   = iLow(0, 0, low_index);
    
    if (rsi > rsi_max) indicator_highest = TRUE; else indicator_highest = FALSE;
    if (rsi < rsi_min) indicator_lowest  = TRUE; else indicator_lowest  = FALSE;
    if (rsi > 0      ) indicator_high    = TRUE; else indicator_high    = FALSE;
    if (rsi < 0      ) indicator_low     = TRUE; else indicator_low     = FALSE;
}


void UpdateTradeStatus()
{   
    error = OrderSelect(OrdersTotal() - 1, SELECT_BY_POS, MODE_TRADES);
    
    if (OrdersTotal() == 0)
    {
        short_trade = FALSE;
        long_trade  = FALSE;
        last_buy_price  = 0;
        last_sell_price = 0;
    }
    else if (OrderType() == OP_SELL)
    {
        short_trade = TRUE;
        long_trade  = FALSE;
        last_sell_price = OrderOpenPrice();
        last_buy_price  = 0;
    }
    else if (OrderType() == OP_BUY)
    {
        short_trade = FALSE;
        long_trade  = TRUE;
        last_buy_price  = OrderOpenPrice();
        last_sell_price = 0;
    }
    else
    {
        Alert("Critical error " + GetLastError());
    }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SendBuy()
{
    error = OrderSend(Symbol(), OP_BUY, i_lots, Ask, slip, 0, 0, name,
                      magic_number, 0, clrLimeGreen);
    NewOrdersPlaced();
}

void SendSell()
{
    error = OrderSend(Symbol(), OP_SELL, i_lots, Bid, slip, 0, 0, name,
                      magic_number, 0, clrHotPink);
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