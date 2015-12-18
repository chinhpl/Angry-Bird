enum I_SIG
{
    MFI,
    CCI
};

int initial_deposit = 0;
bool long_trade          = FALSE;
bool short_trade         = FALSE;
double all_lots          = 0;
double average_price     = 0;
double bands_extra_high  = 0;
double bands_extra_low   = 0;
double bands_high        = 0;
double bands_highest     = 0;
double bands_low         = 0;
double bands_lowest      = 0;
double bands_mid         = 0;
double commission        = 0;
double delta             = 0;
double i_lots            = 0;
double i_takeprofit      = 0;
double last_buy_price    = 0;
double last_sell_price   = 0;
double lots_multiplier   = 0;
double price_target      = 0;
double rsi               = 0;
double rsi_prev          = 0;
double tp_dist           = 0;
double stdev             = 0;
int error                = 0;
int i_test               = 0;
int lotdecimal           = 2;
int magic_number         = 2222;
int previous_time        = 0;
int slip                 = 1000;
int total                = 0;
string comment           = "";
string name              = "Ilan1.6";
uint time_elapsed        = 0;
uint time_start          = GetTickCount();
extern int rsi_max       = 200;
extern int rsi_min       = -100;
extern int rsi_period    = 14;
extern int stddev_period = 14;
extern double exp_base   = 1.7;
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
    Print("Iterations: "   + i_test);
    return (0);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int start()
{
    //--- Works only at the first tick of a new bar
    if (!IsOptimization()) Update();
    if (previous_time == Time[0]) return (0);
    previous_time = Time[0];
    Update();
    double indicator_ = IndicatorSignal();
    //---

    //--- First
    if (OrdersTotal() == 0)
    {
        if (indicator_ == OP_BUY)
        {
            SendBuy();
        }
        else if (indicator_ == OP_SELL)
        {
            SendSell();
        }
        return 0;
    }
    //---

    //--- Cancels
    if (AccountProfit() >= 0)
    {
        if (short_trade)
        {
            //--- Closes sell and opens buy
            if (indicator_ == OP_BUY)
            {
                CloseThisSymbolAll();
                Update();
                SendBuy();
                return 0;
            }
            //--- Take
            if (indicator_ == -500)
            {
                CloseThisSymbolAll();
                return 0;
            }
        }
        if (long_trade)
        {
            //--- Closes buy and opens sell
            if (indicator_ == OP_SELL)
            {
                CloseThisSymbolAll();
                Update();
                SendSell();
                return 0;
            }
            //--- Take
            if (indicator_ == 500)
            {
                CloseThisSymbolAll();
                return 0;
            }
        }
    }
    //---
    
    //--- Proceeding Trades
    if (short_trade && indicator_ == OP_SELL && /*bands_lowest > last_sell_price*/ Bid > last_sell_price + stdev)
    {
        SendSell();
    }
    else if (long_trade && indicator_ == OP_BUY && /*bands_highest < last_buy_price*/ Ask < last_buy_price - stdev)
    {
        SendBuy();
    }
    //---
    return 0;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Update()
{
    total = OrdersTotal();
    // stdev = NormalizeDouble(2 * iStdDev(0, 0, stddev_period, 0, MODE_SMA, PRICE_TYPICAL, 1), Digits);
     stdev = NormalizeDouble(1 / iStdDev(0, 0, stddev_period, 0, MODE_SMA, PRICE_TYPICAL, 1), Digits);

    if (short_trade)
    {
        tp_dist = (Bid - average_price) / Point;
    }
    else if (long_trade)
    {
        tp_dist = (average_price - Ask) / Point;
    }

    if (OrdersTotal() == 0)
    {
        //--- Resets
        all_lots        = 0;
        average_price   = 0;
        commission      = 0;
        i_takeprofit    = 0;
        last_buy_price  = 0;
        last_sell_price = 0;
        i_lots          = lots;
        long_trade      = FALSE;
        short_trade     = FALSE;
        delta           = MarketInfo(Symbol(), MODE_TICKVALUE) * lots;
        //---
    }
    else
    {
        total = OrdersTotal();

         lots_multiplier = MathPow(exp_base, OrdersTotal());
        // lots_multiplier = 1 + ((tp_dist * Point) * exp_base);

        i_lots       = NormalizeDouble(lots * lots_multiplier, lotdecimal);
        commission   = CalculateCommission() * -1;
        all_lots     = CalculateLots();
        delta        = MarketInfo(Symbol(), MODE_TICKVALUE) * all_lots;
        i_takeprofit = MathRound(commission / delta);
    }

    if (!IsOptimization())
    {
        int time_difference = TimeCurrent() - Time[0];
        ObjectSet("Average Price", OBJPROP_PRICE1, average_price);

        Comment("Last Distance: " + tp_dist + " Deviation: " + stdev + " Take Profit: " + i_takeprofit +
                " Lots: " + i_lots + " Time: " + time_difference);
    }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void NewOrdersPlaced()
{
    //--- Prevents bad results showing in tester
    if (IsTesting() && error < 0)
    {
        CloseThisSymbolAll();
        
        while (AccountBalance() >= initial_deposit / 2)
        {
            error = OrderSend(Symbol(), OP_BUY, AccountLeverage() * (AccountBalance() / Ask),
                              Ask, slip, 0, 0, name, magic_number, 0, 0);
                              
            error = OrderSelect(OrdersTotal() - 1, SELECT_BY_POS, MODE_TRADES);
            error = OrderClose(OrderTicket(), OrderLots(), Bid, slip, clrMagenta);
        }
        
        ExpertRemove();
        return;
    }
    //---

    Update();
    UpdateAveragePrice();
    UpdateOpenOrders();
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateAveragePrice()
{
    average_price = 0;
    double count = 0;
    for (int i = 0; i < OrdersTotal(); i++)
    {
        error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
        average_price += OrderOpenPrice() * OrderLots();
        count += OrderLots();
    }
    average_price = NormalizeDouble(average_price / count, Digits);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateOpenOrders()
{
    for (int i = 0; i < OrdersTotal(); i++)
    {
        error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
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
        }/*
        error =
            OrderModify(OrderTicket(), 0, 0,
                        NormalizeDouble(price_target, Digits), 0, clrYellow);*/
        return;
    }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double IndicatorSignal()
{
    double rsi_leg;
    double rsi_mid;

    //--- Indicator selection
    if (indicator == MFI)
    {
        rsi      = iMFI(0, 0, rsi_period, 1);
        rsi_prev = iMFI(0, 0, rsi_period, 2);
        rsi_leg  = iMFI(0, 0, rsi_period, 3);
        rsi_mid  = 50;
    }
    else if (indicator == CCI)
    {
        rsi      = iCCI(0, 0, rsi_period, PRICE_TYPICAL, 1);
        rsi_prev = iCCI(0, 0, rsi_period, PRICE_TYPICAL, 2);
        rsi_leg  = iCCI(0, 0, rsi_period, PRICE_TYPICAL, 3);
        rsi_mid  = 0;
    }
    //---

    bands_highest = iBands(0, 0, stddev_period, 2, 0, PRICE_TYPICAL, MODE_UPPER, 1);
    bands_mid     = iBands(0, 0, stddev_period, 1, 0, PRICE_TYPICAL, MODE_MAIN,  1);
    bands_lowest  = iBands(0, 0, stddev_period, 2, 0, PRICE_TYPICAL, MODE_LOWER, 1);

    if (rsi > rsi_max /*&& rsi < rsi_prev*/) return OP_SELL;
    if (rsi < rsi_min /*&& rsi > rsi_prev*/) return OP_BUY;
    if (rsi > rsi_mid) return  500;
    if (rsi < rsi_mid) return -500;
    return (-1);
}
//+------------------------------------------------------------------+
//| SUBROUTINES                                                      |
//+------------------------------------------------------------------+
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
