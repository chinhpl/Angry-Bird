bool cci_highest = FALSE;
bool cci_lowest  = FALSE;
bool trade_sell  = FALSE;
bool trade_buy   = FALSE;
bool cci_high    = FALSE;
bool cci_low     = FALSE;
double last_order_price = 0;
double band_high        = 0;
double band_low         = 0;
double i_lots           = 0;
int initial_deposit = 0;
int total_orders    = 0;
int iterations      = 0;
int lotdecimal      = 2;
int prev_time       = 0;
int magic_num       = 2222;
int error           = 0;
int slip            = 100;
extern int cci_max      =  180;
extern int cci_min      = -180;
extern int cci_period   =  13;
extern int cci_ma       =  3;
extern int bands_period =  13;
extern double exp       =  1.3;
extern double lots      =  0.01;
uint time_start = GetTickCount();
string name = "Ilan1.6";

int init()
{
    initial_deposit = AccountBalance();
    UpdateBeforeOrder();
    UpdateAfterOrder();
    Debug();
    return 0;
}

int deinit()
{
    uint time_elapsed = GetTickCount() - time_start;
    Print("Time Elapsed: " + time_elapsed);
    Print("Iterations: "   + iterations  );
    return 0;
}

int start()
{
    if (!IsTesting() || IsVisualMode()) Debug();

    /* Idle conditions */
    if (prev_time == Time[0]) return 0; prev_time = Time[0];
    if (trade_sell && AccountProfit() <= 0 && Ask < last_order_price) return 0;
    if (trade_buy  && AccountProfit() <= 0 && Bid > last_order_price) return 0;
    UpdateBeforeOrder();

    /* Closes all orders if there are any */
    if (AccountProfit() >= 0.01) CloseAllOrders();

    /* First order */
    if (OrdersTotal() == 0)
    {
        if (cci_highest) SendOrder(OP_SELL);
        if (cci_lowest)  SendOrder(OP_BUY);
        return 0;
    }

    /* Proceeding orders */
    if (trade_sell && cci_highest && band_low > last_order_price)
        SendOrder(OP_SELL);
    if (trade_buy  && cci_lowest && band_high < last_order_price)
        SendOrder(OP_BUY);
    return 0;
}

void UpdateBeforeOrder()
{   iterations++;
    band_high      = iBands(0, 0, bands_period, 2, 0, PRICE_TYPICAL, MODE_UPPER, 1);
    band_low       = iBands(0, 0, bands_period, 2, 0, PRICE_TYPICAL, MODE_LOWER, 1);
    double cci     = iCCI(0, 0, cci_period, PRICE_TYPICAL, 1);
    double cci_avg = 0;

    for (int i = 1; i <= cci_ma; i++)
        cci_avg += iCCI(0, 0, cci_period, PRICE_TYPICAL, i);

    cci_avg /= cci_ma;

    if (cci_avg > cci_max && cci < cci_avg) cci_highest = 1; else cci_highest = 0;
    if (cci_avg < cci_min && cci > cci_avg) cci_lowest  = 1; else cci_lowest  = 0;
    if (cci_avg > cci_min && cci < cci_avg) cci_high    = 1; else cci_high    = 0;
    if (cci_avg < cci_max && cci > cci_avg) cci_low     = 1; else cci_low     = 0;
}

void UpdateAfterOrder()
{
    double multiplier = MathPow(exp, OrdersTotal());
    i_lots            = NormalizeDouble(lots * multiplier, lotdecimal);

    error = OrderSelect(OrdersTotal() - 1, SELECT_BY_POS, MODE_TRADES);
    if (OrdersTotal() == 0)
    {
        last_order_price = 0;
        total_orders     = 0;
        trade_sell       = FALSE;
        trade_buy        = FALSE;
    }
    else if (OrderType() == OP_SELL)
    {
        last_order_price = OrderOpenPrice();
        total_orders     = OrdersTotal();
        trade_sell       = TRUE;
        trade_buy        = FALSE;
    }
    else if (OrderType() == OP_BUY)
    {
        last_order_price = OrderOpenPrice();
        total_orders     = OrdersTotal();
        trade_sell       = FALSE;
        trade_buy        = TRUE;
    }
    else
    {
        Alert("Critical error " + GetLastError());
    }
}

void SendOrder(int OP_TYPE)
{
    if (OP_TYPE == OP_SELL)
        error = OrderSend(Symbol(), OP_TYPE, i_lots, Bid, slip, 0, 0, name,
                          magic_num, 0, clrHotPink);
    if (OP_TYPE == OP_BUY)
        error = OrderSend(Symbol(), OP_TYPE, i_lots, Ask, slip, 0, 0, name,
                          magic_num, 0, clrLimeGreen);

    if (IsTesting() && error < 0) Kill();
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
    CloseAllOrders();
    while (AccountBalance() >= initial_deposit - 1)
    {
        double _lots = AccountFreeMargin() / Ask;
        error = OrderSend(Symbol(), OP_BUY, _lots, Ask, 0, 0, 0, 0, 0, 0, 0);
        CloseAllOrders();
    }
    ExpertRemove();
}

void Debug()
{
    UpdateAfterOrder();
    UpdateBeforeOrder();

    int time_difference = TimeCurrent() - Time[0];
    Comment("\n- "   +
            "Lots: " + i_lots          + " - " +
            "Time: " + time_difference + " - " +
            "");
}
