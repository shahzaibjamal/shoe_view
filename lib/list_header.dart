import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shoe_view/Helpers/app_info.dart';
import 'package:shoe_view/Helpers/shoe_query_utils.dart';
import 'package:shoe_view/app_status_notifier.dart'; // or use Riverpod if preferred

class ListHeader extends StatefulWidget {
  final double height;
  final TextEditingController searchController;
  final String searchQuery;
  final String sortField;
  final bool sortAscending;
  final ValueChanged<String> onSortFieldChanged;
  final VoidCallback onSortDirectionToggled;
  final VoidCallback onCopyDataPressed;
  final VoidCallback onShareDataPressed;
  final VoidCallback onRefreshDataPressed;
  final VoidCallback onInAppButtonPressed;
  final VoidCallback onSettingsButtonPressed;

  const ListHeader({
    super.key,
    required this.height,
    required this.searchController,
    required this.searchQuery,
    required this.sortField,
    required this.sortAscending,
    required this.onSortFieldChanged,
    required this.onSortDirectionToggled,
    required this.onCopyDataPressed,
    required this.onShareDataPressed,
    required this.onRefreshDataPressed,
    required this.onInAppButtonPressed,
    required this.onSettingsButtonPressed,
  });

  @override
  State<ListHeader> createState() => _ListHeaderState();
}

class _ListHeaderState extends State<ListHeader> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final showDebugButton = context.watch<AppStatusNotifier>().isTest;
    bool isValidDevice = context.read<AppStatusNotifier>().isTest;

    return Stack(
      children: [
        Container(
          height: widget.height,
          color: Colors.blueGrey.shade800,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  // Search Input Field
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: TextField(
                        controller: widget.searchController,
                        decoration: InputDecoration(
                          hintText:
                              'Search: Name, Size (e.g., 42), or Price (e.g., <2500, >1500, =2100)...',
                          hintStyle: TextStyle(
                            color: Colors.blueGrey.shade300,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.white70,
                          ),
                          filled: true,
                          fillColor: Colors.blueGrey.shade700,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10.0,
                            horizontal: 16.0,
                          ),
                          suffixIcon: widget.searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () {
                                    widget.searchController.clear();
                                  },
                                )
                              : null,
                        ),
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 2,
                  ), // Add spacing between TextField and icon
                  IconButton(
                    icon: Icon(
                      Icons.help_outline,
                      color: Colors.white.withValues(
                        alpha: 0.8,
                      ), // Reduced opacity
                      size: 32, // Slightly larger than default (24)
                    ),
                    onPressed: () {
                      FocusScope.of(context).unfocus(); // Dismiss keyboard

                      Future.delayed(Duration(milliseconds: 100), () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Search Help'),
                            content: Text.rich(
                              TextSpan(
                                style: TextStyle(fontSize: 14),
                                children: [
                                  TextSpan(
                                    text: 'Smart Search Guide\n\n',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '• ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Name or keyword: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'e.g. "Jordan", "black", "leather"\n',
                                  ),
                                  TextSpan(
                                    text: '• ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Size: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '42 or multiple like 42|43|44\n',
                                  ),
                                  TextSpan(
                                    text: '• ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Price: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '<2500, >1500, =2100, ~3000 (±500)\n',
                                  ),
                                  TextSpan(
                                    text: '• ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Shipment ID: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '# followed by ID (e.g. #102)\n',
                                  ),
                                  TextSpan(
                                    text: '• ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Limit results: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(text: 'lim<10, lim>5, lim~8\n\n'),
                                  TextSpan(
                                    text: 'Example: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Jordan 42 >2000 lim<5\n',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        'Combine filters for powerful results.',
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Got it'),
                              ),
                            ],
                          ),
                        );
                      });
                    },
                    tooltip: 'Search Help',
                  ),
                ],
              ),
              // Sort and Control Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: widget.onSettingsButtonPressed,
                    tooltip: 'Settings',
                  ),
                  IconButton(
                    icon: const Icon(Icons.diamond, color: Colors.white),
                    onPressed: widget.onInAppButtonPressed,
                    tooltip: 'In-app action',
                  ),
                  if (isValidDevice)
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: widget.onRefreshDataPressed,
                      tooltip: 'Refresh data',
                    ),
                  IconButton(
                    icon: const Icon(Icons.content_copy, color: Colors.white),
                    onPressed: widget.onCopyDataPressed,
                    tooltip: 'Copy data',
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_sharp, color: Colors.white),
                    onPressed: widget.onShareDataPressed,
                    tooltip: 'Share data',
                  ),
                  const SizedBox(width: 0),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: widget.sortField,
                      dropdownColor: Colors.blueGrey.shade700,
                      icon: const Icon(Icons.sort, color: Colors.white),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          widget.onSortFieldChanged(newValue);
                        }
                      },
                      items: ['ItemId', 'size', 'sellingPrice', 'sold', 'n/a']
                          .map((field) {
                            return DropdownMenuItem(
                              value: field,
                              child: Text(
                                ShoeQueryUtils.formatLabel(field),
                                style: TextStyle(
                                  color: widget.sortField == field
                                      ? Colors.amberAccent
                                      : Colors.white,
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      widget.sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      color: Colors.white,
                    ),
                    onPressed: widget.onSortDirectionToggled,
                    tooltip: 'Toggle Sort Direction',
                  ),
                ],
              ),
            ],
          ),
        ),

        if (showDebugButton)
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              icon: const Icon(Icons.bug_report, color: Colors.redAccent),
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Debug Mode Activated')));
              },
              tooltip: 'Debug Mode',
            ),
          ),
      ],
    );
  }
}
