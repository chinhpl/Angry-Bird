bool long_trade        = FALSE;
bool short_trade       = FALSE;
double average_price   = 0;
double i_lots          = 0;
double i_takeprofit    = 0;
double last_buy_price  = 0;
double last_sell_price = 0;
double price_target    = 0;
double commission      = 0;
double all_lots        = 0;
double delta           = 0;
double rsi             = 0;
int error              = 0;
int lotdecimal         = 2;
int magic_number       = 2222;
int pipstep            = 0;
int previous_time      = 0;
int slip               = 1;
int total              = 0;
string comment         = "";
string name            = "Ilan1.6";
extern int rsi_max     = 60.0;
extern int rsi_min     = 60.0;
extern int rsi_period  = 17;
extern int dev_period  = 2;
extern double exponent_base = 1.5;
extern double takeprofit_ratio = 0.5;
extern double lots     = 0.01;

int init()
{
    if (rsi_min > rsi_max) ExpertRemove();
    total = CountTrades();
    if (total)
    {
        last_buy_price  = FindLastBuyPrice();
        last_sell_price = FindLastSellPrice();
        NewOrdersPlaced();
    }
    ObjectCreate("Average Price", OBJ_HLINE, 0, 0, average_price, 0, 0, 0, 0);
    ObjectSet("Average Price", OBJPROP_COLOR, clrHotPink);
    return (0);
}

int deinit() { return (0); }
int start()
{ /* Sleeps until next bar opens if a trade is made */
    if (!IsOptimization()) Update();
    if (previous_time == Time[0]) return (0);
    previous_time = Time[0];
    Update();
    for (int i = 0; i < total - 1; i++)
    {
        error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
        {
                if (OrderType() == OP_BUY && OrderProfit() >= (OrderCommission() * -1))
                {
                    error = OrderClose(OrderTicket(), OrderLots(), Bid, slip, clrBlue);
                    last_buy_price = FindLastBuyPrice();
                    NewOrdersPlaced();
                }    
                if (OrderType() == OP_SELL && OrderProfit() >= (OrderCommission() * -1))
                {
                    error = OrderClose(OrderTicket(), OrderLots(), Ask, slip, clrBlue);
                    last_sell_price = FindLastSellPrice();
                    NewOrdersPlaced();
                }    
        }
    }
    total = CountTrades();

    if (total == 0)
    { /* All the actions that occur when a trade is signaled */
        if (IndicatorSignal() == OP_BUY)
        {
            error = OrderSend(Symbol(), OP_BUY, i_lots, Ask, slip, 0, 0, name,
                              magic_number, 0, clrLimeGreen);
            last_buy_price = Ask;
            NewOrdersPlaced();
        }
        else if (IndicatorSignal() == OP_SELL)
        {
            error = OrderSend(Symbol(), OP_SELL, i_lots, Bid, slip, 0, 0, name,
                              magic_number, 0, clrHotPink);
            last_sell_price = Bid;
            NewOrdersPlaced();
        }
    }
    else if (short_trade && Bid > last_sell_price + pipstep * Point)
    {
        if (IndicatorSignal() == OP_SELL)
        {
            error = OrderSend(Symbol(), OP_SELL, i_lots, Bid, slip, 0, 0, name,
                              magic_number, 0, clrHotPink);
            last_sell_price = Bid;
            NewOrdersPlaced();
        }
    }
    else if (long_trade && Ask < last_buy_price - pipstep * Point)
    {
        if (IndicatorSignal() == OP_BUY)
        {
            error = OrderSend(Symbol(), OP_BUY, i_lots, Ask, slip, 0, 0, name,
                              magic_number, 0, clrLimeGreen);
            last_buy_price = Ask;
            NewOrdersPlaced();
        }
    }
    return (0);
}

void Update()
{
    total = CountTrades();
    double lots_multiplier = MathPow(exponent_base, total);
    i_lots = NormalizeDouble(lots * lots_multiplier, lotdecimal);
    pipstep = 2 * iStdDev(NULL, 0, dev_period, 0, MODE_SMA, PRICE_TYPICAL, 0) / Point;
    
    if (total == 0)
    { /* Reset */
        short_trade    = FALSE;
        long_trade     = FALSE;
        delta          = MarketInfo(Symbol(), MODE_TICKVALUE) * lots;
        commission     = 0;
        all_lots       = 0;
        i_takeprofit   = 0;
        average_price  = 0;
        last_buy_price = 0;
        last_sell_price = 0;
    }

    if (!IsOptimization())
    {
        int time_difference = TimeCurrent() - Time[0];
        int tp_dist         = 0;
        double order_spread = 0;
        if (short_trade)
        {
            tp_dist      = (Bid - last_sell_price) / Point;
            order_spread = (last_sell_price - price_target) / Point;
        }
        if (long_trade)
        {
            tp_dist      = (last_buy_price - Ask) / Point;
            order_spread = (price_target - last_buy_price) / Point;
        }
        name = AccountBalance() + "\n";
        ObjectSet("Average Price", OBJPROP_PRICE1, average_price);

        Comment("Trade Distance: " + tp_dist + " Pipstep: " + pipstep +
                " Spread: " + order_spread + " Take Profit: " + i_takeprofit +
                " Lots: " + i_lots + " Time: " + time_difference);
    }
}

void NewOrdersPlaced()
{ /* Prevents bad results showing in tester */
    if (IsTesting() && error < 0)
    {
        ExpertRemove();
    }
    total          = CountTrades();
    commission     = CalculateCommission() * -1;
    all_lots       = CalculateLots();
    delta          = MarketInfo(Symbol(), MODE_TICKVALUE) * all_lots;
    i_takeprofit =
        MathRound((commission / delta) + (all_lots * takeprofit_ratio / delta));
        
    UpdateAveragePrice();
    UpdateOpenOrders();
}

void UpdateAveragePrice()
{
    average_price = 0;
    double count  = 0;
    for (int i = 0; i < total; i++)
    {
        error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
        {
            average_price += OrderOpenPrice() * OrderLots();
            count         += OrderLots();
        }
    }
    average_price = NormalizeDouble(average_price / count, Digits);
    
}

void UpdateOpenOrders()
{
    for (int i = 0; i < total; i++)
    {
        error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
        {
            if (OrderType() == OP_BUY)
            {
                price_target = average_price +
                               NormalizeDouble((i_takeprofit * Point), Digits);
                short_trade = FALSE;
                long_trade  = TRUE;
            }
            else if (OrderType() == OP_SELL)
            {
                price_target = average_price -
                               NormalizeDouble((i_takeprofit * Point), Digits);
                short_trade = TRUE;
                long_trade  = FALSE;
            }
            error = OrderModify(
                OrderTicket(), NULL, NormalizeDouble(OrderStopLoss(), Digits),
                NormalizeDouble(price_target, Digits), 0, Yellow);
        }
    }
}

int IndicatorSignal()
{
    rsi = iMFI(NULL, 0, rsi_period, 1);

    if (rsi > rsi_max) return OP_SELL;
    if (rsi < rsi_min) return OP_BUY;
    return (-1);
}
/******************************************************************************
*******************************************************************************
******************************************************************************/

int CountTrades()
{
    int count = 0;
    for (int trade = OrdersTotal() - 1; trade >= 0; trade--)
    {
        error = OrderSelect(trade, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
            if (OrderType() == OP_SELL || OrderType() == OP_BUY) count++;
    }
    return (count);
}

void CloseThisSymbolAll()
{
    for (int trade = OrdersTotal() - 1; trade >= 0; trade--)
    {
        error = OrderSelect(trade, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
        {
            if (OrderType() == OP_BUY)
                error = OrderClose(OrderTicket(), OrderLots(), Bid, slip, Blue);
            if (OrderType() == OP_SELL)
                error = OrderClose(OrderTicket(), OrderLots(), Ask, slip, Red);
        }
    }
}

double CalculateProfit()
{
    double Profit = 0;
    for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
    {
        error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
            if (OrderType() == OP_BUY || OrderType() == OP_SELL)
                Profit += OrderProfit();
    }
    return (Profit);
}

double CalculateCommission()
{
    double p_commission = 0;
    for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
    {
        error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
            if (OrderType() == OP_BUY || OrderType() == OP_SELL)
                p_commission += OrderCommission();
    }
    return (p_commission);
}

double CalculateLots()
{
    double lot = 0;
    for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
    {
        error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
            if (OrderType() == OP_BUY || OrderType() == OP_SELL)
            {
                lot += OrderLots();
            }
    }
    return (lot);
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
                ticketnumber     = oldticketnumber;
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
