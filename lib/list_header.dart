import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shoe_view/Helpers/app_info.dart';
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
  int _tapCount = 0;
  DateTime? _lastTapTime;
  bool _isValidDevice = false;

  @override
  void initState() {
    super.initState();
    _checkDevice();
  }

  void _handleTapSequence() {
    final now = DateTime.now();

    if (_lastTapTime == null ||
        now.difference(_lastTapTime!) > Duration(seconds: 1)) {
      _tapCount = 0;
    }

    _tapCount++;
    _lastTapTime = now;

    if (_tapCount == 5) {
      bool isTest = context.read<AppStatusNotifier>().isTest;
      context.read<AppStatusNotifier>().updateTest(!isTest);
      _tapCount = 0;
    }
  }

  void _checkDevice() async {
    final deviceId = await AppInfoUtility.getDeviceId();
    final validDevices = ['TP1A.220624.014'];
    setState(() {
      _isValidDevice = validDevices.contains(deviceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final showDebugButton = context.watch<AppStatusNotifier>().isTest;

    return Stack(
      children: [
        GestureDetector(
          onTap: _handleTapSequence,
          child: Container(
            height: widget.height,
            color: Colors.blueGrey.shade800,
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 20.0,
              bottom: 8.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search Input Field
                Padding(
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
                    if (_isValidDevice)
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            widget.onSortFieldChanged(newValue);
                          }
                        },
                        items:
                            [
                              'ItemId',
                              'size',
                              'sold',
                              'repaired',
                              'sellingPrice',
                            ].map((field) {
                              return DropdownMenuItem(
                                value: field,
                                child: Text(
                                  field == 'sellingPrice'
                                      ? 'Price'
                                      : field[0].toUpperCase() +
                                            field.substring(1),
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
                      onPressed: widget.onSortDirectionToggled,
                      tooltip: 'Toggle Sort Direction',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        if (showDebugButton)
          Positioned(
            top: 8,
            right: 8,
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
