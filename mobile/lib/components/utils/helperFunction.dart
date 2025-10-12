// items.dart

class Items {
  static List<dynamic> _items = []; // shared private list

  // Function to retrieve items (with parameter)
  static List<dynamic> getItems(List<dynamic> data) {
    _items = data;
    print("Items retrieved: $_items");
    return _items; // return stored list
  }

  // Function to return items (no parameter needed)
  static List<dynamic> returnItems() {
    return _items;
  }
}
