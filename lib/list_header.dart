import 'package:flutter/material.dart';

class ListHeader extends StatelessWidget {
  final double height;
  final TextEditingController searchController;
  final String searchQuery;
  final String sortField;
  final bool sortAscending;
  final ValueChanged<String> onSortFieldChanged;
  final VoidCallback onSortDirectionToggled;
  // New callback for copying the displayed data
 final VoidCallback onCopyDataPressed;

  const ListHeader({
    super.key,
    required this.height,
    required this.searchController,
    required this.searchQuery,
    required this.sortField,
    required this.sortAscending,
    required this.onSortFieldChanged,
    required this.onSortDirectionToggled,
   required this.onCopyDataPressed, // Added new required parameter
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: Colors.blueGrey.shade800,
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0, bottom: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Input Field
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search: Name, Size (e.g., 42), or Price (e.g., <2500, >1500, =2100)...',
                hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.blueGrey.shade700,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                suffixIcon: searchQuery.isNotEmpty ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  onPressed: () {
                    searchController.clear();
                    // Listener on searchController handles the state update in ShoeListView
                  },
                ) : null,
              ),
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
            ),
          ),

          // Sort and Copy controls
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // --- NEW COPY BUTTON ---
              IconButton(
                icon: const Icon(Icons.content_copy, color: Colors.white),
                onPressed: () => onCopyDataPressed(),
                tooltip: 'Copy currently displayed shoes details to clipboard',
              ),
              const SizedBox(width: 16),
              // --- END NEW COPY BUTTON ---

              const Text('Sort By:', style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: sortField,
                  dropdownColor: Colors.blueGrey.shade700,
                  icon: const Icon(Icons.sort, color: Colors.white),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      onSortFieldChanged(newValue);
                    }
                  },
                  items: [
                    DropdownMenuItem(
                      value: 'itemId',
                      child: Text('ID', style: TextStyle(color: sortField == 'itemId' ? Colors.amberAccent : Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: 'sellingPrice',
                      child: Text('Price', style: TextStyle(color: sortField == 'sellingPrice' ? Colors.amberAccent : Colors.white)),
                    ),
                  ],
                ),
              ),
              // Button for toggling sort direction
              IconButton(
                icon: Icon(
                  sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Colors.white,
                ),
                onPressed: onSortDirectionToggled,
                tooltip: 'Toggle Sort Direction',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
