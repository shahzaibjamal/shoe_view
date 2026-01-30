import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shoe_view/Helpers/shoe_query_utils.dart';
import 'package:shoe_view/app_status_notifier.dart';

class ListHeader extends StatefulWidget {
  final double height;
  final TextEditingController searchController;
  final String searchQuery;
  final ShoeCategory selectedCategory;
  final List<String> suggestions;
  final int itemCount;
  final ValueChanged<ShoeCategory> onCategoryChanged;
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
  final int selectedCount;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final VoidCallback onBulkCopy;
  final VoidCallback onBulkCollage;

  const ListHeader({
    super.key,
    required this.height,
    required this.searchController,
    required this.searchQuery,
    required this.selectedCategory,
    required this.suggestions,
    required this.itemCount,
    required this.onCategoryChanged,
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
    this.selectedCount = 0,
    required this.onClearSelection,
    required this.onBulkDelete,
    required this.onBulkCopy,
    required this.onBulkCollage,
  });

  @override
  State<ListHeader> createState() => _ListHeaderState();
}

class _ListHeaderState extends State<ListHeader> {
  final GlobalKey _menuKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  late FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      return;
    }

    final renderBox = _menuKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate if we should align to right or left
    final bool isRightSide = position.dx > screenWidth / 2;
    const double menuWidth = 180.0;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: _toggleOverlay,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            top: position.dy + size.height + 8,
            left: isRightSide ? (position.dx + size.width - menuWidth) : position.dx,
            child: Material(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: Container(
                width: menuWidth,
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildOverlayItem(
                      icon: Icons.refresh_rounded,
                      label: 'Refresh Data',
                      onTap: widget.onRefreshDataPressed,
                    ),
                    _buildOverlayItem(
                      icon: Icons.local_shipping_rounded,
                      label: 'Send Samples',
                      onTap: widget.onSampleSendPressed,
                    ),
                    _buildOverlayItem(
                      icon: Icons.save_rounded,
                      label: 'Save Data',
                      onTap: widget.onSaveDataPressed,
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

  Widget _buildSelectionBar() {
    return SizedBox(
      height: 50,
      child: Row(
        key: const ValueKey('selection_bar'),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: widget.onClearSelection,
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.selectedCount} selected',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          _HeaderIconButton(
            icon: Icons.content_copy_rounded,
            tooltip: 'Bulk Copy',
            onPressed: widget.onBulkCopy,
          ),
          const SizedBox(width: 12),
          _HeaderIconButton(
            icon: Icons.share_rounded,
            tooltip: 'Smart Collage',
            onPressed: widget.onBulkCollage,
          ),
          const SizedBox(width: 12),
          _HeaderIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Bulk Delete',
            onPressed: widget.onBulkDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBarRow() {
    final appStatus = context.read<AppStatusNotifier>();
    final showDebugButton = appStatus.isTest;

    return Row(
      key: const ValueKey('search_bar'),
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: TextField(
              controller: widget.searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search collection...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withOpacity(0.6),
                  size: 20,
                ),
                suffixIcon: widget.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: Colors.white60),
                        onPressed: () {
                          widget.searchController.clear();
                          // No need to unfocus here to keep keyboard up for typing new query,
                          // or unfocus if user wants to clear and close.
                          // existing behavior was unfocus. I'll check user intent or stick to existing behavior.
                          // existing: FocusScope.of(context).unfocus();
                          // Let's keep it simple.
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: Colors.white70,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _HeaderIconButton(
          icon: Icons.help_outline_rounded,
          tooltip: 'Search Help',
          onPressed: () {
            FocusScope.of(context).unfocus();
            _showSearchHelp(context);
          },
        ),
        const SizedBox(width: 8),
        if (showDebugButton) ...[
          const _HeaderIconButton(
            icon: Icons.bug_report_rounded,
            onPressed: null,
          ),
          const SizedBox(width: 8),
        ],
        _HeaderIconButton(
          key: _menuKey,
          icon: Icons.more_vert_rounded,
          tooltip: 'More Actions',
          onPressed: _toggleOverlay,
        ),
      ],
    );
  }

  Widget _buildOverlayItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        _toggleOverlay();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.blueGrey.shade800),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.blueGrey.shade800,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appStatus = context.watch<AppStatusNotifier>();
    final showDebugButton = appStatus.isTest;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueGrey.shade900, Colors.indigo.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: widget.selectedCount > 0
                        ? _buildSelectionBar()
                        : _buildSearchBarRow(),
                    ),
                if (widget.selectedCount == 0) ...[
                  const SizedBox(height: 12),
                  // 🏷️ Category Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _CategoryChip(
                          label: 'Available',
                          isSelected:
                              widget.selectedCategory == ShoeCategory.available,
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            widget.onCategoryChanged(ShoeCategory.available);
                          },
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: 'Sold',
                          isSelected:
                              widget.selectedCategory == ShoeCategory.sold,
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            widget.onCategoryChanged(ShoeCategory.sold);
                          },
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: 'Repaired',
                          isSelected:
                              widget.selectedCategory == ShoeCategory.repaired,
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            widget.onCategoryChanged(ShoeCategory.repaired);
                          },
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: 'Upcoming',
                          isSelected:
                              widget.selectedCategory == ShoeCategory.upcoming,
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            widget.onCategoryChanged(ShoeCategory.upcoming);
                          },
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: 'Internal',
                          isSelected:
                              widget.selectedCategory == ShoeCategory.internal,
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            widget.onCategoryChanged(ShoeCategory.internal);
                          },
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // ⚙️ Control & Sort Row
                  Row(
                    children: [
                      // Sorting Group
                      Expanded(
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(Icons.sort_rounded,
                                      size: 18,
                                      color: Colors.white.withOpacity(0.6)),
                                  Positioned(
                                    top: -8,
                                    right: -8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.amberAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        widget.itemCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: widget.sortField,
                                    dropdownColor: Colors.indigo.shade900,
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down,
                                        color: Colors.white54, size: 20),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                    onChanged: (String? val) {
                                      FocusScope.of(context).unfocus();
                                      if (val != null) {
                                        widget.onSortFieldChanged(val);
                                      }
                                    },
                                    items: [
                                      'ItemId',
                                      'size',
                                      'sellingPrice',
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
                              ),
                              _HeaderIconButton(
                                icon: widget.sortAscending
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                size: 18,
                                onPressed: () {
                                  FocusScope.of(context).unfocus();
                                  widget.onSortDirectionToggled();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Quick Action Buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _HeaderIconButton(
                            icon: Icons.content_copy_rounded,
                            tooltip: 'Copy',
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              widget.onCopyDataPressed();
                            },
                          ),
                          _HeaderIconButton(
                            icon: Icons.share_rounded,
                            tooltip: 'Share Collage',
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              widget.onShareDataPressed();
                            },
                          ),
                          _HeaderIconButton(
                            icon: Icons.settings_rounded,
                            tooltip: 'Settings',
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              widget.onSettingsButtonPressed();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSearchHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: Colors.amber[700]),
            const SizedBox(width: 12),
            const Text('Smart Search'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpItem('Name', 'Jordan, black, retro'),
            _buildHelpItem('Size', '42 or 42|43 (multi)'),
            _buildHelpItem('Price', '<2500, >1500, ~2100'),
            _buildHelpItem('Shipment', '#102'),
            _buildHelpItem('Inventory', 'lim<10, lim~5'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Example: Jordan 42 >2000 lim<5',
                style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String label, String example) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 13),
          children: [
            TextSpan(text: '• $label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: example, style: TextStyle(color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final double size;

  const _HeaderIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white.withOpacity(0.85), size: size),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      splashRadius: 20,
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.9)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.indigo.shade900 : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
class _SelectionActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const _SelectionActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color ?? Colors.white),
      tooltip: tooltip,
      onPressed: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
    );
  }
}
