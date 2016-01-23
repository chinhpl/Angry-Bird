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
extern int rsi_slow      = 5;
extern int stddev_period = 11;
extern double exp_base   = 1.4;
extern double lots       = 0.01;

int init() {
  initial_deposit = AccountBalance();
  UpdateBeforeOrder();
  UpdateAfterOrder();
  Debug();
  return 0;
}

int deinit() {
  time_elapsed = GetTickCount() - time_start;
  Print("Time Elapsed: " + time_elapsed);
  Print("Iterations: " + iterations);
  return 0;
}

int start() {
  if (!IsTesting() || IsVisualMode()) Debug();

  /* Idle conditions */
  if (previous_time == Time[0]) return 0;
  previous_time = Time[0];
  UpdateBeforeOrder();

  /* Closes all orders */
  if (total_orders > 0 && AccountProfit() > 0) {
    if (short_trade && indicator_low) CloseAllOrders();
    if (long_trade && indicator_high) CloseAllOrders();
  }

  /* First order */
  if (total_orders == 0) {
    if (indicator_lowest) SendOrder(OP_BUY);
    if (indicator_highest) SendOrder(OP_SELL);
    return 0;
  }

  /* Proceeding Orders */
  if (short_trade && indicator_highest && bands_lowest > last_sell_price)
    SendOrder(OP_SELL);
  else if (long_trade && indicator_lowest && bands_highest < last_buy_price)
    SendOrder(OP_BUY);
  return 0;
}

void UpdateBeforeOrder() { iterations++;
  double rsi     = iCCI(0, 0, rsi_period, PRICE_TYPICAL, 1);
  double rsi_avg = 0;

  for (int i = 1; i <= rsi_slow; i++) {
    rsi_avg += iCCI(0, 0, rsi_period, PRICE_TYPICAL, i);
  }
  rsi_avg /= rsi_slow;

  bands_highest = iMA(0, 0, stddev_period, 0, MODE_SMA, PRICE_HIGH, 1);
  bands_lowest  = iMA(0, 0, stddev_period, 0, MODE_SMA, PRICE_LOW,  1);

  if (rsi_avg > rsi_max && rsi < rsi_avg)        indicator_highest = TRUE;
                                            else indicator_highest = FALSE;
  if (rsi_avg < rsi_min && rsi > rsi_avg)        indicator_lowest  = TRUE;
                                            else indicator_lowest  = FALSE;
  if (rsi > rsi_max) indicator_high = TRUE; else indicator_high    = FALSE;
  if (rsi < rsi_min) indicator_low  = TRUE; else indicator_low     = FALSE;
}

void UpdateAfterOrder() {
  lots_multiplier = MathPow(exp_base, OrdersTotal());
  i_lots          = NormalizeDouble(lots * lots_multiplier, lotdecimal);

  error = OrderSelect(OrdersTotal() - 1, SELECT_BY_POS, MODE_TRADES);
  if (OrdersTotal() == 0) {
    total_orders    = 0;
    last_buy_price  = 0;
    last_sell_price = 0;
    long_trade      = FALSE;
    short_trade     = FALSE;
  } else if (OrderType() == OP_SELL) {
    total_orders    = OrdersTotal();
    last_sell_price = OrderOpenPrice();
    last_buy_price  = 0;
    long_trade      = FALSE;
    short_trade     = TRUE;
  } else if (OrderType() == OP_BUY) {
    total_orders    = OrdersTotal();
    last_buy_price  = OrderOpenPrice();
    last_sell_price = 0;
    long_trade      = TRUE;
    short_trade     = FALSE;
  } else {
    Alert("Critical error " + GetLastError());
  }
}

void SendOrder(int OP_TYPE) {
  double price       = 0;
  double order_color = 0;

  if (OP_TYPE == OP_SELL) {
    price       = Bid;
    order_color = clrHotPink;
  }
  if (OP_TYPE == OP_BUY) {
    price       = Ask;
    order_color = clrLimeGreen;
  }
  error = OrderSend(Symbol(), OP_TYPE, i_lots, price, slip, 0, 0, name,
                    magic_number, 0, order_color);
  if (error == -1) Kill();
  UpdateAfterOrder();
}

void CloseAllOrders() {
  for (int i = OrdersTotal() - 1; i >= 0; i--) {
    error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
    if (OrderType() == OP_BUY)
      error = OrderClose(OrderTicket(), OrderLots(), Bid, slip, clrBlue);
    if (OrderType() == OP_SELL)
      error = OrderClose(OrderTicket(), OrderLots(), Ask, slip, clrBlue);
  }
  UpdateAfterOrder();
}

void Kill() {
  if (IsTesting() && error < 0) {
    CloseAllOrders();
    while (AccountBalance() >= initial_deposit - 1) {
      error = OrderSend(Symbol(), OP_BUY, AccountFreeMargin() / Ask, Ask, slip,
                        0, 0, name, magic_number, 0, 0);
      CloseAllOrders();
    }
    ExpertRemove();
  }
}

void Debug() {
  UpdateBeforeOrder();
  UpdateAfterOrder();
  int time_difference = TimeCurrent() - Time[0];
  Comment("Lots: " + i_lots + " Time: " + time_difference);
}
