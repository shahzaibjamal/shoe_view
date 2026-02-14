import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shoe_view/Helpers/shoe_query_utils.dart';
import 'package:shoe_view/app_status_notifier.dart';
import 'package:shoe_view/shoe_model.dart';

class ListHeader extends StatefulWidget {
  final double height;
  final TextEditingController searchController;
  final String searchQuery;
  final List<String> suggestions;
  final int itemCount;
  final VoidCallback onFilterButtonPressed;
  final VoidCallback onCopyDataPressed;
  final VoidCallback onShareDataPressed;
  final VoidCallback onRefreshDataPressed;
  final VoidCallback onInAppButtonPressed;
  final VoidCallback onSettingsButtonPressed;
  final VoidCallback onSampleSendPressed;
  final VoidCallback onSaveDataPressed;
  final VoidCallback onCloseAppPressed;
  final int selectedCount;
  final int filterCount;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;
  final VoidCallback onBulkCopy;
  final VoidCallback onBulkCollage;
  final ShoeCategory selectedCategory;
  final ValueChanged<ShoeCategory> onCategoryChanged;

  const ListHeader({
    super.key,
    required this.height,
    required this.searchController,
    required this.searchQuery,
    required this.suggestions,
    required this.itemCount,
    this.filterCount = 0,
    required this.onFilterButtonPressed,
    required this.onCopyDataPressed,
    required this.onShareDataPressed,
    required this.onRefreshDataPressed,
    required this.onInAppButtonPressed,
    required this.onSettingsButtonPressed,
    required this.onSampleSendPressed,
    required this.onSaveDataPressed,
    required this.onCloseAppPressed,
    this.selectedCount = 0,
    required this.onClearSelection,
    required this.onBulkDelete,
    required this.onBulkCopy,
    required this.onBulkCollage,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  State<ListHeader> createState() => _ListHeaderState();
}

class _ListHeaderState extends State<ListHeader> with WidgetsBindingObserver {
  final GlobalKey _menuKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  late FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// 🎯 Fix: Reset focus when app resumes from background (e.g., after sharing to WhatsApp)
  /// This fixes the keyboard not opening issue on Android.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Unfocus first, then recreate the node to fix any broken focus state
      _searchFocusNode.unfocus();
      
      // Schedule a microtask to recreate the focus node after the frame
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _searchFocusNode.dispose();
            _searchFocusNode = FocusNode();
          });
        }
      });
    }
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
                color: Theme.of(context).colorScheme.surface,
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
                    _buildOverlayItem(
                      icon: Icons.exit_to_app_rounded,
                      label: 'Exit App',
                      onTap: widget.onCloseAppPressed,
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

  Widget _buildCategoryTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: ShoeCategory.values.map((cat) {
          final isSelected = widget.selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: () => widget.onCategoryChanged(cat),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Colors.white.withOpacity(0.25)
                      : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected 
                        ? Colors.white.withOpacity(0.4) 
                        : Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Text(
                  ShoeQueryUtils.formatLabel(cat.name),
                  style: TextStyle(
                    color: Colors.white.withOpacity(isSelected ? 1.0 : 0.6),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
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
          icon: Icons.tune_rounded,
          tooltip: 'Filters & Sort',
          badgeCount: widget.filterCount, // 🎯 Filter Badge
          onPressed: () {
            FocusScope.of(context).unfocus();
            widget.onFilterButtonPressed();
          },
        ),
        const SizedBox(width: 8),
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
            Icon(icon, size: 20, color: Theme.of(context).iconTheme.color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // 🎯 Center content to fill height naturally
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: widget.selectedCount > 0
                        ? _buildSelectionBar()
                        : _buildSearchBarRow(),
                  ),
                  if (widget.selectedCount == 0) ...[
                    const SizedBox(height: 10),
                    _buildCategoryTabs(),
                    const SizedBox(height: 10),
                    // ⚙️ Compact Action Row
                    Row(
                      children: [
                        // Item Count Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 14, color: Colors.indigo.shade200),
                              const SizedBox(width: 6),
                              Text(
                                '${widget.itemCount} Items',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Debug Indicator
                        const Opacity(
                          opacity: 0.6,
                          child: Row(
                            children: [
                              Icon(Icons.bug_report_rounded, size: 14, color: Colors.amberAccent),
                              SizedBox(width: 4),
                              Text('DEBUG', style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Quick Action Buttons
                        _HeaderIconButton(
                          icon: Icons.content_copy_rounded,
                          tooltip: 'Copy current list',
                          showSuccessCheck: true,
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            widget.onCopyDataPressed();
                          },
                        ),
                        const SizedBox(width: 8),
                        _HeaderIconButton(
                          icon: Icons.share_rounded,
                          tooltip: 'Share Collage',
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            widget.onShareDataPressed();
                          },
                        ),
                        const SizedBox(width: 8),
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
                ],
              ),
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

class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final double size;
  final bool showSuccessCheck;
  final int badgeCount;

  const _HeaderIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.size = 24,
    this.showSuccessCheck = false,
    this.badgeCount = 0,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePress() async {
    if (widget.onPressed == null) return;

    HapticFeedback.lightImpact();
    
    // Quick scale animation
    await _controller.forward();
    await _controller.reverse();

    widget.onPressed!();

    // Only show success check for copy buttons
    if (widget.showSuccessCheck && mounted) {
      setState(() => _isSuccess = true);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _isSuccess = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(
      _isSuccess ? Icons.check_circle_rounded : widget.icon,
      key: ValueKey(_isSuccess),
      color: _isSuccess
          ? Colors.greenAccent
          : Colors.white.withOpacity(0.85),
      size: widget.size,
    );

    // 🎯 Wrap with Badge if needed
    if (widget.badgeCount > 0 && !_isSuccess) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.amberAccent,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '${widget.badgeCount}',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: iconWidget,
        ),
        tooltip: widget.tooltip,
        onPressed: _handlePress,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        splashRadius: 20,
      ),
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
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
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
