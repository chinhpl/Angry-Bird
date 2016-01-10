bool indicator_high      = FALSE;
bool indicator_highest   = FALSE;
bool indicator_low       = FALSE;
bool indicator_lowest    = FALSE;
bool long_trade          = FALSE;
bool short_trade         = FALSE;
double bands_highest     = 0;
double bands_lowest      = 0;
double buffer_profit     = 0;
double i_lots            = 0;
double last_buy_price    = 0;
double last_sell_price   = 0;
int error                = 0;
int initial_deposit      = 0;
int iterations           = 0;
int lotdecimal           = 2;
int magic_number         = 2222;
int previous_time        = 0;
int slip                 = 100;
int total_orders         = 0;
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
    UpdateBeforeOrder();
    UpdateAfterOrder();
    Debug();
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
    if (!IsTesting() || IsVisualMode()) Debug();

    /* Idle conditions */
    if (previous_time == Time[0]) return 0;
    previous_time = Time[0];

    /* Closes all orders */
    if (total_orders > 0 && AccountProfit() > 0 - buffer_profit)
    {
        UpdateBeforeOrder();
        if (short_trade && indicator_low) CloseAllOrders();
        if (long_trade && indicator_high) CloseAllOrders();
    }

    /* First order */
    if (total_orders == 0)
    {
        UpdateBeforeOrder();
        if (indicator_lowest) SendOrder(OP_BUY);
        if (indicator_highest) SendOrder(OP_SELL);
        return 0;
    }

    /* Closes last orders */
    if (total_orders > 1)
    {
        error = OrderSelect(total_orders - 1, SELECT_BY_POS, MODE_TRADES);
        if (OrderProfit() > -OrderCommission())
        {
            UpdateBeforeOrder();
            if (short_trade && indicator_lowest && bands_highest < last_sell_price)
            {
                error = OrderClose(OrderTicket(), OrderLots(), Ask, slip, clrWhiteSmoke);
                buffer_profit += OrderProfit() + OrderCommission();
                UpdateAfterOrder();
                return 0;
            }
            if (long_trade && indicator_highest && bands_lowest > last_buy_price)
            {
                error = OrderClose(OrderTicket(), OrderLots(), Bid, slip, clrWhiteSmoke);
                buffer_profit += OrderProfit() + OrderCommission();
                UpdateAfterOrder();
                return 0;
            }
        }
    }

    /* Proceeding Orders */
    if (short_trade && Bid > last_sell_price)
    {
        UpdateBeforeOrder();
        if (indicator_highest && bands_lowest > last_sell_price)
            SendOrder(OP_SELL);
    }
    else if (long_trade && Ask < last_buy_price)
    {
        UpdateBeforeOrder();
        if (indicator_lowest && bands_highest < last_buy_price)
            SendOrder(OP_BUY);
    }
    return 0;
}

void UpdateBeforeOrder()
{
    double rsi = 0;
    for (int i = 1; i <= rsi_slow; i++)
        rsi += iCCI(0, 0, rsi_period, PRICE_TYPICAL, i);
    rsi /= rsi_slow;

    double rsi_hi  = (rsi_max + rsi_max + rsi_min) / 3;
    double rsi_low = (rsi_max + rsi_min + rsi_min) / 3;
    
    double high_index = iHighest(0, 0, MODE_HIGH, stddev_period * total_orders, 1);
    double low_index = iLowest(0, 0, MODE_LOW, stddev_period * total_orders, 1);
    bands_highest = iHigh(0, 0, high_index) + MarketInfo(0, MODE_SPREAD) * Point;
    bands_lowest  = iLow(0, 0, low_index) - MarketInfo(0, MODE_SPREAD) * Point;

    if (rsi > rsi_max) indicator_highest = TRUE; else indicator_highest = FALSE;
    if (rsi < rsi_min) indicator_lowest  = TRUE; else indicator_lowest  = FALSE;
    if (rsi > rsi_hi ) indicator_high    = TRUE; else indicator_high    = FALSE;
    if (rsi < rsi_low) indicator_low     = TRUE; else indicator_low     = FALSE;
}

void UpdateAfterOrder()
{
    double lots_multiplier = MathPow(exp_base, OrdersTotal());
    i_lots          = NormalizeDouble(lots * lots_multiplier, lotdecimal);

    error = OrderSelect(OrdersTotal() - 1, SELECT_BY_POS, MODE_TRADES);
    if (OrdersTotal() == 0)
    {
        short_trade     = FALSE;
        long_trade      = FALSE;
        last_buy_price  = 0;
        last_sell_price = 0;
        total_orders    = 0;
        buffer_profit   = 0;
    }
    else if (OrderType() == OP_SELL)
    {
        short_trade     = TRUE;
        long_trade      = FALSE;
        last_sell_price = OrderOpenPrice();
        last_buy_price  = 0;
        total_orders    = OrdersTotal();
    }
    else if (OrderType() == OP_BUY)
    {
        short_trade     = FALSE;
        long_trade      = TRUE;
        last_buy_price  = OrderOpenPrice();
        last_sell_price = 0;
        total_orders    = OrdersTotal();
    }
    else
    {
        Alert("Critical error " + GetLastError());
    }
}

void SendOrder(int OP_TYPE)
{
    double price;
    color order_color;

    if (OP_TYPE == OP_SELL)
    {
        price = Bid;
        order_color = clrHotPink;
    }
    if (OP_TYPE == OP_BUY)
    {
        price = Ask;
        order_color = clrLimeGreen;
    }

    error = OrderSend(Symbol(), OP_TYPE, i_lots, price, slip, 0, 0, name,
                      magic_number, 0, order_color);
    if (error == -1) Kill();
    UpdateAfterOrder();
}

void CloseAllOrders()
{
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
        if (OrderType() == OP_BUY)
            error = OrderClose(OrderTicket(), OrderLots(), Bid, slip, clrBlue);
        if (OrderType() == OP_SELL)
            error = OrderClose(OrderTicket(), OrderLots(), Ask, slip, clrBlue);
    }
    UpdateAfterOrder();
}

void Kill()
{
    if (IsTesting() && error < 0)
    {
        CloseAllOrders();
        while (AccountBalance() >= initial_deposit - 1)
        {
            error = OrderSend(Symbol(), OP_BUY, AccountFreeMargin() / Ask, Ask,
                              slip, 0, 0, name, magic_number, 0, 0);

            CloseAllOrders();
        }
        ExpertRemove();
    }
}

void Debug()
{
    UpdateBeforeOrder();
    UpdateAfterOrder();

    ObjectSet("bands_highest", OBJPROP_PRICE1, bands_highest);
    ObjectSet("bands_lowest", OBJPROP_PRICE1, bands_lowest);

    int time_difference = TimeCurrent() - Time[0];
    Comment("Time: "          + time_difference              + "\n" +
            "Lots: "          + i_lots                       + "\n" +
            "Profit Buffer: " + buffer_profit                + "\n" +
            "STD Period: "    + stddev_period * total_orders + "\n");
}
