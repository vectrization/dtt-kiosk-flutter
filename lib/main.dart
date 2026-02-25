import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';

const String baseApiUrl = "https://kiosk-worker.0mugunthanruthreshwaran.workers.dev";
const String basePageUrl = "https://dttkiosk.pages.dev";

final currency = NumberFormat.currency(
  locale: 'en_SG',
  symbol: '\$',
);

void main() {
  runApp(ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: "Kiosk",
        initialRoute: "/",
        routes: {
          '/': (context) => const IdlePage(),
          '/menu': (context) => const MenuPage(),
          '/checkout': (context) => const CheckoutPage(),
          '/completion': (context) => const CompletionPage()
        },
      )
    )
  );
}

class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String vendorId;
  final String vendorName;
  final String imageUrl;
  final List<String> tags;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.vendorId,
    required this.vendorName,
    required this.imageUrl,
    required this.tags,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json["id"],
      name: json["name"],
      description: json["description"] ?? "",
      price: (json["price"] as num).toDouble() / 100,
      vendorId: json["vendor_id"],
      vendorName: json["vendor_name"],
      imageUrl: json["image_url"] ?? "",
      tags: (json["tags"] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class CartItem {
  final MenuItem item;
  int quantity;

  CartItem(this.item, {this.quantity = 1});

  double get unitPrice => item.price;
  double get totalPrice => unitPrice * quantity;
}

class AppState extends ChangeNotifier {
  List<MenuItem> menu = [];
  List<CartItem> cart = [];
  List<String> selectedMealTypes = [];
  List<String> selectedDietTags = [];
  List<String> selectedOtherTags = [];
  bool isLoading = false;
  bool get hasActiveFilters => selectedMealTypes.isNotEmpty || selectedDietTags.isNotEmpty || selectedOtherTags.isNotEmpty;

  List<String> allTags() {
    final tags = <String>{};
    for (var m in menu) {
      tags.addAll(m.tags);
    }
    return tags.toList()..sort();
  }

  List<MenuItem> get filteredMenu {
    if (!hasActiveFilters) return menu;

    return menu.where((m) {
      final itemTags = m.tags.map((t) => t.toLowerCase()).toSet();
      final matchMealTypes = selectedMealTypes.isEmpty ? true : selectedMealTypes.every((tag) => itemTags.contains(tag.toLowerCase()));
      final matchDietTags = selectedDietTags.isEmpty ? true : selectedDietTags.every((tag) => itemTags.contains(tag.toLowerCase()));
      final matchOtherTags = selectedOtherTags.isEmpty ? true : selectedOtherTags.every((tag) => itemTags.contains(tag.toLowerCase()));
      return matchMealTypes && matchDietTags && matchOtherTags;
    }).toList();
  }

  void toggleMealType(String type) {
    if (selectedMealTypes.contains(type)) {
      selectedMealTypes.remove(type);
    } else {
      selectedMealTypes.add(type);
    }
    notifyListeners();
  }

  void toggleDietTag(String tag) {
    if (selectedDietTags.contains(tag)) {
      selectedDietTags.remove(tag);
    } else {
      selectedDietTags.add(tag);
    }
    notifyListeners();
  }

  void toggleOtherTag(String tag) {
    if (selectedOtherTags.contains(tag)) {
      selectedOtherTags.remove(tag);
    } else {
      selectedOtherTags.add(tag);
    }
    notifyListeners();
  }

  int countMealsWithTag(String tag) => menu.where((m) => m.tags.contains(tag)).length;

  Future<void> loadMenu() async {
    isLoading = true;
    notifyListeners();

    final response = await http.get(Uri.parse("$baseApiUrl/meal"));

    if (response.statusCode != 200) {
      isLoading = false;
      notifyListeners();
      throw Exception("Failed to load menu. Note: using school wifi may block the domain used for the server.");
    }

    final List<dynamic> data = jsonDecode(response.body);

    menu = data.map((json) => MenuItem.fromJson(json)).toList();

    isLoading = false;
    notifyListeners();
  }

  void addToCart(MenuItem item) {
    final existing = cart.where((c) => c.item.id == item.id).toList();

    if (existing.isNotEmpty) {
      existing.first.quantity++;
    } else {
      cart.add(CartItem(item));
    }

    notifyListeners();
  }

  void increment(CartItem item) {
    item.quantity++;
    notifyListeners();
  }

  void decrement(CartItem item) {
    if (item.quantity > 1) {
      item.quantity--;
    } else {
      cart.remove(item);
    }
    notifyListeners();
  }

  void removeFromCart(CartItem item) {
    cart.remove(item);
    notifyListeners();
  }

  double get subtotal => cart.fold(0, (sum, item) => sum + item.totalPrice);
  double get tax => subtotal * 0.09;
  double get total => subtotal + tax;
}

class IdlePage extends StatelessWidget {
  const IdlePage({super.key});
  
  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      state.cart.clear();
      state.notifyListeners();
    });

    return Scaffold(
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Welcome!\nPress below to start ordering.", textAlign: TextAlign.center),
            ElevatedButton(onPressed: () {
                Navigator.pushNamed(context, "/menu");
              },
              child: Text("Order Now")
            )
        ]
      ))
    );
  }
}

class _MenuPageState extends State<MenuPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadMenu();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const _MenuPageUI();
  }
}

class _MenuPageUI extends StatelessWidget {
  const _MenuPageUI();
  
  Widget _dietIcon(String tag) {
    switch (tag.toLowerCase()) {
      case "veg":
        return Icon(
          MdiIcons.foodApple,
          size: 16,
          color: Colors.greenAccent,
        );
      case "non-veg":
        return Icon(
          MdiIcons.foodDrumstick,
          size: 16,
          color: Colors.redAccent,
        );
      case "halal":
        return Icon(
          MdiIcons.foodHalal,
          size: 16,
          color: Colors.blueAccent,
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildBackButton(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushNamed(context, "/"),
        ),
        const Text(
          "Menu",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final state = context.watch<AppState>();

    final allTags = state.menu.expand((m) => m.tags).toSet();

    final mealTypes = ["Breakfast", "Lunch", "Snacks"];
    final dietTags = ["Veg", "Non-Veg", "Halal"];
    final otherTags = allTags.difference({...mealTypes, ...dietTags}).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...mealTypes.map((type) {
            final count = state.menu.where((m) => m.tags.contains(type)).length;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text("$type ($count)"),
                selected: state.selectedMealTypes.contains(type),
                onSelected: (_) => state.toggleMealType(type),
              ),
            );
          }).toList(),

          const SizedBox(width: 16),

          ...dietTags.map((tag) {
            final count = state.menu.where((m) => m.tags.map((t) => t.toLowerCase()).contains(tag.toLowerCase())).length;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text("$tag ($count)"),
                selected: state.selectedDietTags.contains(tag),
                onSelected: (_) => state.toggleDietTag(tag),
              ),
            );
          }).toList(),

          const SizedBox(width: 16),

          PopupMenuButton<String>(
            tooltip: "More Filters",
            itemBuilder: (context) {
              return otherTags.map((tag) {
                final count = state.menu.where((m) => m.tags.contains(tag)).length;
                return CheckedPopupMenuItem(
                  value: tag,
                  checked: state.selectedOtherTags.contains(tag),
                  child: Text("$tag ($count)"),
                );
              }).toList();
            },
            onSelected: (tag) => state.toggleOtherTag(tag),
            child: const ActionChip(
              avatar: Icon(Icons.tune, size: 18),
              label: Text("More Filters"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedSection(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.menu.isEmpty) return const SizedBox();

    final featuredMeals = state.menu.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 125,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: featuredMeals.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final meal = featuredMeals[index];

              return _featuredCard(context, meal);
            },
          ),
        ),
      ],
    );
  }

  Widget _featuredCard(BuildContext context, MenuItem meal) {
    final state = context.read<AppState>();

    return Container(
      width: 275,
      height: 75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            child: Container(
              width: 90,
              height: double.infinity,
              color: Colors.grey[300],
              child: meal.imageUrl.isNotEmpty ? Image.network(meal.imageUrl, fit: BoxFit.cover) : const Icon(Icons.fastfood, size: 32),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          meal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Row(
                        children: meal.tags.map((tag) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: _dietIcon(tag),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        currency.format(meal.price),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(
                        height: 28,
                        child: ElevatedButton(
                          onPressed: () => state.addToCart(meal),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          child: const Text("ADD"),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
 
  Widget _buildCartPanel(BuildContext context) {
    final state = context.watch<AppState>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "Order Details",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: state.cart.isEmpty
                ? const Center(child: Text("Cart is empty"))
                : ListView.builder(
                    itemCount: state.cart.length,
                    itemBuilder: (context, index) {
                      final cartItem = state.cart[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cartItem.item.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              cartItem.item.vendorName,
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12),
                            ),

                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                _quantityStepper(cartItem, state),
                                Text(
                                  currency.format(cartItem.totalPrice),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const Divider(),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Column(
              children: [

                _summaryRow("Items Total", state.subtotal),

                _summaryRow("Tax (9%)", state.tax),

                const SizedBox(height: 8),

                _summaryRow("To Pay", state.total, isBold: true),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: state.cart.isEmpty ? null : () { Navigator.pushNamed(context, "/checkout"); },
                    child: const Text("Place Order"),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
          ),
          Text(
            currency.format(amount),
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }

  Widget _quantityStepper( CartItem cartItem, AppState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => state.decrement(cartItem),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.remove, size: 18),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              cartItem.quantity.toString(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => state.increment(cartItem),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.add, size: 18),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMenuScrollView(BuildContext context) {
    final state = context.watch<AppState>();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([

              _buildBackButton(context),
              const SizedBox(height: 16),

              _buildFilterBar(context),
              const SizedBox(height: 24),

             if (!context.read<AppState>().hasActiveFilters) ...[
                _buildSectionHeader("Featured"),
                const SizedBox(height: 16),
                _buildFeaturedSection(context),
                const SizedBox(height: 32),
              ],

              _buildSectionHeader("All Items"),
              const SizedBox(height: 16),

            ]),
          ),
        ),

        if (state.isLoading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final meal = state.filteredMenu[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _menuCard(context, meal),
                  );
                },
                childCount: state.filteredMenu.length,
              ),
            )
          ),
      ],
    );
  }

  Widget _menuCard(BuildContext context, MenuItem meal) {
    final state = context.read<AppState>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 90,
                height: 90,
                color: Colors.grey[300],
                child: meal.imageUrl.isNotEmpty
                    ? Image.network(meal.imageUrl, fit: BoxFit.cover)
                    : const Icon(Icons.fastfood),
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          meal.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Row(
                        children: meal.tags.map((tag) => Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: _dietIcon(tag),
                        )).toList(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Text(
                    meal.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], height: 1.4),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        currency.format(meal.price),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => state.addToCart(meal),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text("ADD"),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    //final state = context.watch<AppState>();
    final size = MediaQuery.of(context).size;
    final landscape = size.width > size.height;

    return Scaffold(
      body: landscape
          ? Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Colors.grey[100],
                    child: _buildMenuScrollView(context),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: _buildCartPanel(context),
                ),
              ],
            )
          : Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Colors.grey[100],
                    child: _buildMenuScrollView(context),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _buildCartPanel(context),
                ),
              ],
            ),
    );
  }
}

class MenuPage extends StatefulWidget { 
  const MenuPage({super.key});
  State<MenuPage> createState() => _MenuPageState();
}

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  Widget _buildBackButton(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushNamed(context, "/menu"),
        ),
        const Text(
          "Checkout",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildOrderSummary(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Order Summary",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),

        Expanded(
          child: state.cart.isEmpty
              ? const Center(child: Text("Your cart is empty"))
              : ListView.builder(
                  itemCount: state.cart.length,
                  itemBuilder: (context, index) {
                    final cartItem = state.cart[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cartItem.item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "x${cartItem.quantity}",
                                style: TextStyle(
                                    color: Colors.grey[600]),
                              ),
                              Text(
                                currency.format(
                                    cartItem.totalPrice),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                        ],
                      ),
                    );
                  },
                ),
        ),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),

        _summaryRow("Subtotal", state.subtotal),
        _summaryRow("Tax (9%)", state.tax),
        const SizedBox(height: 12),
        _summaryRow("Total", state.total, isBold: true),
      ],
    );
  }

  Widget _buildPaymentSection(BuildContext context, AppState state) {
    String selectedMethod = "Card";

    return StatefulBuilder(
      builder: (context, setState) {
        Widget paymentOption(String label, IconData icon) {
          final isSelected = selectedMethod == label;

          return GestureDetector(
            onTap: () => setState(() => selectedMethod = label),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(icon, color: isSelected ? Colors.white : Colors.black),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        Widget buildDynamicPaymentUI() {
          switch (selectedMethod) {
            case "Card":
              return Column(
                children: const [
                  TextField(
                    decoration: InputDecoration(
                      labelText: "Card Number",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: "Name on Card",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: "Expiry (MM/YY)",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: "CVV",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            case "PayNow":
              return Column(
                children: [
                  Container(
                    height: 180,
                    width: 180,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.qr_code, size: 100),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Scan this QR using your banking app",
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            case "GrabPay":
              return Column(
                children: const [
                  Icon(Icons.account_balance_wallet, size: 80),
                  SizedBox(height: 16),
                  Text(
                    "Open your Grab app\nand approve the payment",
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            case "NETS":
              return Column(
                children: const [
                  Icon(Icons.credit_card, size: 80),
                  SizedBox(height: 16),
                  Text(
                    "Please insert or tap your NETS card",
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            default:
              return const SizedBox();
          }
        }

        return Column(
          children: [
            Expanded(
              child: ScrollConfiguration(
                behavior: const ScrollBehavior()
                    .copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Payment",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      buildDynamicPaymentUI(),

                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 24),

                      const Text(
                        "Alternative Payment Methods",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      paymentOption("Card", Icons.credit_card),
                      const SizedBox(height: 12),
                      paymentOption("PayNow", Icons.qr_code),
                      const SizedBox(height: 12),
                      paymentOption("GrabPay", Icons.account_balance_wallet),
                      const SizedBox(height: 12),
                      paymentOption("NETS", Icons.credit_card),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: state.cart.isEmpty
                    ? null
                    : () {
                        Navigator.pushNamed(context, '/completion');
                      },
                child: Text(
                  "Pay ${currency.format(state.total)}",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryRow(String label, double amount,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight:
                  isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 16,
            ),
          ),
          Text(
            currency.format(amount),
            style: TextStyle(
              fontWeight:
                  isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final size = MediaQuery.of(context).size;
    final landscape = size.width > size.height;

    return Scaffold(
      body: Container(
        color: Colors.grey[100],
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBackButton(context),
            const SizedBox(height: 24),

            Expanded(
              child: Center(
                child: Container(
                  width: size.width * 0.65,
                  height: size.height * 0.85,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: landscape
                      ? Row(
                          children: [
                            Expanded(flex: 3, child: _buildOrderSummary(state)),
                            const SizedBox(width: 48),
                            Expanded(flex: 2, child: _buildPaymentSection(context, state)),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(flex: 3, child: _buildOrderSummary(state)),
                            const SizedBox(height: 32),
                            Expanded(flex: 2, child: _buildPaymentSection(context, state)),
                          ],
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CompletionPage extends StatefulWidget {
  const CompletionPage({super.key});

  @override
  State<CompletionPage> createState() => _CompletionPageState();
}

class _CompletionPageState extends State<CompletionPage> {
  String? orderId;
  String? error;
  bool loading = true;
  int secondsRemaining = 10;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    createOrder();
  }

  Future<void> createOrder() async {
    final state = context.read<AppState>();

    try {
      final response = await http.post(
        Uri.parse("$baseApiUrl/order"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "items": state.cart.map((c) => {
                "id": c.item.id,
                "name": c.item.name,
                "quantity": c.quantity,
                "unit_price": (c.unitPrice * 100).toInt(),
              }).toList()
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to create order");
      }

      final data = jsonDecode(response.body);
      setState(() {
        orderId = data["id"];
        loading = false;
      });

    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Widget buildQRCode() {
    if (orderId == null) return SizedBox();

    final trackUrl = "$basePageUrl/track?id=$orderId";

    return QrImageView(
      data: trackUrl,
      version: QrVersions.auto,
      size: 200,
    );
  }

  void startCountdown() {
    secondsRemaining = 10;

    timer?.cancel();
    timer = Timer.periodic(Duration(seconds: 1), (t) {
      if (secondsRemaining == 0) {
        t.cancel();
        Navigator.pushReplacementNamed(context, "/idle");
      } else {
        setState(() {
          secondsRemaining--;
        });
      }
    });
  }
  void extendTimer() {
    setState(() {
      secondsRemaining = 10;
    });
  }
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        body: Center(child: Text("Error: $error")),
      );
    }

    //final trackingUrl = "$basePageUrl/track?id=$orderId";
    final trackingUrl = "https://www.youtube.com/watch?v=dQw4w9WgXcQ";

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 120, color: Colors.green),
              const SizedBox(height: 24),
              const Text(
                "Order Placed!",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text("Scan to track your order"),
              const SizedBox(height: 32),

              QrImageView(
                data: trackingUrl,
                version: QrVersions.auto,
                size: 220,
              ),

              const SizedBox(height: 24),
              Text(
                "Order ID: $orderId",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 40),
              
              Text(
                "Returning to idle in $secondsRemaining",
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: extendTimer,
                child: Text("Stay on this screen"),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  state.cart.clear();
                  state.notifyListeners();
                  Navigator.popUntil(context, ModalRoute.withName("/"));
                },
                child: const Text("Back to Home"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     body: Center(
  //       child: Container(
  //         padding: const EdgeInsets.all(48),
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             const Icon(Icons.check_circle, size: 120, color: Colors.green),
  //             const SizedBox(height: 24),
  //             const Text(
  //               "Order Completed!",
  //               style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
  //             ),
  //             const SizedBox(height: 16),
  //             const Text(
  //               "Your food is being prepared.\nThank you!",
  //               textAlign: TextAlign.center,
  //             ),
  //             const SizedBox(height: 40),
  //             ElevatedButton(
  //               onPressed: () {
  //                 Navigator.popUntil(context, ModalRoute.withName("/"));
  //               },
  //               child: const Text("Back to Home"),
  //             )
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }
