enum I_SIG
{
    RSI, MFI, CCI
};


bool long_trade        = FALSE;
bool short_trade       = FALSE;
double average_price   = 0;
double i_lots          = 0;
double i_takeprofit    = 0;
double last_buy_price  = 0;
double last_sell_price = 0;
double price_target    = 0;
double commission      = 0;
double lots_multiplier = 0;
double all_lots        = 0;
double delta           = 0;
double rsi             = 0;
double tp_dist         = 0;
double rsi_prev = 0;
double rsi_mid     = 0;
int error              = 0;
int lotdecimal         = 2;
int magic_number       = 2222;
int pipstep            = 0;
int previous_time      = 0;
int slip               = 0;
int total              = 0;
int i_test             = 0;
string comment         = "";
string name            = "Ilan1.6";
extern int rsi_max     = 200;
extern int rsi_min     = -100;
extern int rsi_period  = 14;
extern int stddev_period = 14;
extern double exp_base = 1.7;
extern double lots             = 0.01;
extern I_SIG indicator = 2;
uint time_start = GetTickCount();
uint time_elapsed = 0;


int init()
{
    if (IsTesting())
    {
        if (rsi_min > rsi_max) ExpertRemove();
        if (rsi_max > 100 && indicator != CCI) ExpertRemove();
        if (rsi_min < 0   && indicator != CCI) ExpertRemove();
    }
    total = OrdersTotal();
    if (total)
    {
        last_buy_price  = FindLastBuyPrice();
        last_sell_price = FindLastSellPrice();
        Update();
        NewOrdersPlaced();
    }
    ObjectCreate("Average Price", OBJ_HLINE, 0, 0, average_price, 0, 0, 0, 0);
    
    return (0);
}

int deinit()
{
    time_elapsed = GetTickCount() - time_start;
    Print("Time Elapsed: " + time_elapsed);
    return (0);
}

int start()
{ /* Sleeps until next bar opens if a trade is made */
    if (!IsOptimization()) Update();
    if (previous_time == Time[0]) return (0);
    previous_time = Time[0];
    Update();
    
    double indicator_result = IndicatorSignal();
    
    /* Cancels */
    if (short_trade && indicator_result == OP_BUY && AccountProfit() >= 0)
    {
        CloseThisSymbolAll();
        Update();
        error = OrderSend(Symbol(), OP_BUY, i_lots, Ask, slip, 0, 0, name,
                              magic_number, 0, clrLimeGreen);
        last_buy_price = Ask;
        NewOrdersPlaced();
        return 0;
    }    
    else if (long_trade && indicator_result == OP_SELL && AccountProfit() >= 0)
    {
        CloseThisSymbolAll();
        Update();
        error = OrderSend(Symbol(), OP_SELL, i_lots, Bid, slip, 0, 0, name,
                              magic_number, 0, clrHotPink);
        last_sell_price = Bid;
        NewOrdersPlaced();
        return 0;
    }
    else if (short_trade && indicator_result == -500 && AccountProfit() >= 0)
    {
        CloseThisSymbolAll();
        return 0;
    }
    else if (long_trade && indicator_result == 500 && AccountProfit() >= 0)
    {
        CloseThisSymbolAll();
        return 0;
    }
    
    if (long_trade && Bid > average_price)
    {
        for (int i = 0; i < total - 1; i++)
        {
            error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
            if (OrderOpenPrice() > average_price && OrderProfit() >= OrderCommission() * -1)
            {
                error = OrderClose(OrderTicket(), OrderLots(), Bid, slip, clrBlue);
                NewOrdersPlaced();
            }
            else if (OrderOpenPrice() < average_price)
            {
                break;
            }
        }
        last_buy_price = FindLastBuyPrice();
        return 0;
    }
    else if (short_trade && Ask < average_price)
    {
        for (i = 0; i < total - 1; i++)
        {
            error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
            if (OrderOpenPrice() < average_price && OrderProfit() >= OrderCommission() * -1)
            {
                error = OrderClose(OrderTicket(), OrderLots(), Ask, slip, clrBlue);
                NewOrdersPlaced();
            }
            else if (OrderOpenPrice() > average_price)
            {
                break;
            }
        }
        last_sell_price = FindLastSellPrice();
        return 0;
    }
    
    /* All the actions that occur when a trade is signaled */
    if (total == 0)
    {
        if (indicator_result == OP_BUY)
        {
            error = OrderSend(Symbol(), OP_BUY, i_lots, Ask, slip, 0, 0, name,
                              magic_number, 0, clrLimeGreen);
            last_buy_price = Ask;
            NewOrdersPlaced();
        }
        else if (indicator_result == OP_SELL)
        {
            error = OrderSend(Symbol(), OP_SELL, i_lots, Bid, slip, 0, 0, name,
                              magic_number, 0, clrHotPink);
            last_sell_price = Bid;
            NewOrdersPlaced();
        }
    }
    else if (short_trade && indicator_result == OP_SELL && Bid > last_sell_price + pipstep * Point)
    {
            error = OrderSend(Symbol(), OP_SELL, i_lots, Bid, slip, 0, 0, name,
                              magic_number, 0, clrHotPink);
            last_sell_price = Bid;
            NewOrdersPlaced();
    }
    else if (long_trade && indicator_result == OP_BUY && Ask < last_buy_price - pipstep * Point)
    {
            error = OrderSend(Symbol(), OP_BUY, i_lots, Ask, slip, 0, 0, name,
                              magic_number, 0, clrLimeGreen);
            last_buy_price = Ask;
            NewOrdersPlaced();
    }
    return (0);
}

void Update()
{
    total = OrdersTotal();
    
    pipstep = (1 / iStdDev(0, 0, stddev_period, 0, MODE_SMA, PRICE_TYPICAL, 0)) / Point;    
    if (total == 0)
    { /* Reset */
        short_trade     = FALSE;
        long_trade      = FALSE;
        delta           = MarketInfo(Symbol(), MODE_TICKVALUE) * lots;
        commission      = 0;
        all_lots        = 0;
        i_takeprofit    = 0;
        average_price   = 0;
        last_buy_price  = 0;
        last_sell_price = 0;
        i_lots          = lots;
    }
    
    if (!IsOptimization())
    {
        if (short_trade)
        {
            tp_dist      = (Bid - last_sell_price) / Point;
        }
        else if (long_trade)
        {
            tp_dist      = (last_buy_price - Ask) / Point;
        }
        
        int time_difference = TimeCurrent() - Time[0];
        ObjectSet("Average Price", OBJPROP_PRICE1, average_price);

        Comment("Last Distance: " + tp_dist + " Pipstep: " + pipstep + " Take Profit: " + i_takeprofit +
                " Lots: " + i_lots + " Time: " + time_difference);
    }
}

void NewOrdersPlaced()
{ /* Prevents bad results showing in tester */
    if (IsTesting() && error < 0)
    {
        while (AccountBalance() > 20)
        {
            error = OrderSend(Symbol(), OP_BUY, AccountFreeMargin() / Bid,
                              Ask, slip, 0, 0, name, magic_number, 0, 0);
            CloseThisSymbolAll();
        }
        ExpertRemove();
    }
    total = OrdersTotal();
    commission      = CalculateCommission() * -1;
    all_lots        = CalculateLots();
    lots_multiplier = MathPow(exp_base, OrdersTotal());
    i_lots          = NormalizeDouble(lots * lots_multiplier, lotdecimal);
    delta = MarketInfo(Symbol(), MODE_TICKVALUE) * all_lots;
    i_takeprofit = MathRound((commission / delta) + (all_lots / delta));
    
    UpdateAveragePrice();
    UpdateOpenOrders();
}

void UpdateAveragePrice()
{
    average_price = 0;
    double count = 0;
    for (int i = 0; i < total; i++)
    {
        error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
        {
            average_price += OrderOpenPrice() * (OrderLots() / OrderCommission());
            count += (OrderLots() / OrderCommission());
        }
    }
    average_price = NormalizeDouble(average_price / count, Digits);
}

void UpdateOpenOrders()
{
    for (int i = 0; i < CountTrades(); i++)
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
            error =
                OrderModify(OrderTicket(), 0, 0,
                            NormalizeDouble(price_target, Digits), 0, clrYellow);
        }
    }
}

double IndicatorSignal()
{    
    switch (indicator)
    {
        case RSI:
        {
            rsi      = iRSI(0, 0, rsi_period, PRICE_TYPICAL, 1);
            rsi_prev = iRSI(0, 0, rsi_period, PRICE_TYPICAL, 2);
            rsi_mid  = 50;
            break;
        }
        case MFI:
        {
            rsi      = iMFI(0, 0, rsi_period, 1);
            rsi_prev = iMFI(0, 0, rsi_period, 2);
            rsi_mid  = 50;
            break;
        }
        case CCI:
        {
            rsi      = iCCI(0, 0, rsi_period, PRICE_TYPICAL, 1);
            rsi_prev = iCCI(0, 0, rsi_period, PRICE_TYPICAL, 2);
            rsi_mid  = 0;
            break;
        }
    }

    if (rsi > rsi_max)  return OP_SELL;
    if (rsi < rsi_min)  return OP_BUY;
    if (rsi < rsi_mid) return -500;
    if (rsi > rsi_mid) return  500;
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
                error = OrderClose(OrderTicket(), OrderLots(), Bid, slip, clrBlue);
            if (OrderType() == OP_SELL)
                error = OrderClose(OrderTicket(), OrderLots(), Ask, slip, clrBlue);
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
