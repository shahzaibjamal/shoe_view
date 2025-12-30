import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shoe_view/Helpers/shoe_query_utils.dart';
import 'package:shoe_view/app_status_notifier.dart';

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
  final VoidCallback onSampleSendPressed;
  final VoidCallback onSaveDataPressed;

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
    required this.onSampleSendPressed,
    required this.onSaveDataPressed,
  });

  @override
  State<ListHeader> createState() => _ListHeaderState();
}

class _ListHeaderState extends State<ListHeader> {
  final GlobalKey _menuKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  void _toggleOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      return;
    }

    final renderBox = _menuKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Transparent barrier to dismiss when clicking outside
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleOverlay,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),

          // Dropdown container next to 3 dots
          Positioned(
            top: position.dy + renderBox.size.height,
            left: position.dx,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Data',
                      onPressed: () {
                        _toggleOverlay();
                        widget.onRefreshDataPressed();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.local_shipping),
                      tooltip: 'Send Sample Shoes',
                      onPressed: () {
                        _toggleOverlay();
                        widget.onSampleSendPressed();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.save),
                      tooltip: 'Save Data',
                      onPressed: () {
                        _toggleOverlay();
                        widget.onSaveDataPressed();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final appStatus = context.watch<AppStatusNotifier>();
    final showDebugButton = appStatus.isTest;

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
              // 🔍 Search Row
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: TextField(
                        controller: widget.searchController,
                        decoration: InputDecoration(
                          hintText:
                              'Search: Name, Size (42), Price (<2500, >1500, =2100)...',
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
                                  onPressed: () =>
                                      widget.searchController.clear(),
                                )
                              : null,
                        ),
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    icon: Icon(
                      Icons.help_outline,
                      color: Colors.white.withOpacity(0.8),
                      size: 28,
                    ),
                    tooltip: 'Search Help',
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      Future.delayed(const Duration(milliseconds: 100), () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Search Help'),
                            content: const Text(
                              'Smart Search Guide:\n\n'
                              '• Name: "Jordan", "black"\n'
                              '• Size: 42 or 42|43|44\n'
                              '• Price: <2500, >1500, =2100, ~3000\n'
                              '• Shipment ID: #102\n'
                              '• Limit: lim<10, lim>5, lim~8\n\n'
                              'Example: Jordan 42 >2000 lim<5',
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
                  ),
                ],
              ),

              // ⚙️ Control Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    tooltip: 'Settings',
                    onPressed: widget.onSettingsButtonPressed,
                  ),
                  IconButton(
                    icon: const Icon(Icons.diamond, color: Colors.white),
                    tooltip: 'In-app action',
                    onPressed: widget.onInAppButtonPressed,
                  ),
                  IconButton(
                    icon: const Icon(Icons.content_copy, color: Colors.white),
                    tooltip: 'Copy data',
                    onPressed: widget.onCopyDataPressed,
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_sharp, color: Colors.white),
                    tooltip: 'Share data',
                    onPressed: widget.onShareDataPressed,
                  ),

                  // ✅ Only show 3 dots when isTest is true
                  if (appStatus.isTest)
                    IconButton(
                      key: _menuKey,
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      tooltip: 'More actions',
                      onPressed: _toggleOverlay,
                    ),

                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: widget.sortField,
                      dropdownColor: Colors.blueGrey.shade700,
                      icon: const Icon(Icons.sort, color: Colors.white),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      onChanged: (String? newValue) {
                        if (newValue != null)
                          widget.onSortFieldChanged(newValue);
                      },
                      items:
                          [
                            'ItemId',
                            'size',
                            'sellingPrice',
                            'sold',
                            'n/a',
                            'repaired',
                          ].map((field) {
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
                          }).toList(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      widget.sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      color: Colors.white,
                    ),
                    tooltip: 'Toggle Sort Direction',
                    onPressed: widget.onSortDirectionToggled,
                  ),
                ],
              ),
            ],
          ),
        ),

        // 🐞 Debug button
        if (showDebugButton)
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              icon: const Icon(Icons.bug_report, color: Colors.redAccent),
              tooltip: 'Debug Mode',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Debug Mode Activated')),
                );
              },
            ),
          ),
      ],
    );
  }
}
