import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class GestureService {
  static final GestureService instance = GestureService._init();
  GestureService._init();

  // Gesture callbacks
  final Map<String, Function> _gestureCallbacks = {};

  // Register gesture callback
  void registerGesture(String key, Function callback) {
    _gestureCallbacks[key] = callback;
  }

  // Unregister gesture callback
  void unregisterGesture(String key) {
    _gestureCallbacks.remove(key);
  }

  // Create swipe detector
  Widget swipeDetector({
    required Widget child,
    VoidCallback? onSwipeLeft,
    VoidCallback? onSwipeRight,
    VoidCallback? onSwipeUp,
    VoidCallback? onSwipeDown,
    double threshold = 50.0,
  }) {
    return GestureDetector(
      onPanEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond;
        
        // Horizontal swipe
        if (velocity.dx.abs() > velocity.dy.abs()) {
          if (velocity.dx > threshold) {
            onSwipeRight?.call();
          } else if (velocity.dx < -threshold) {
            onSwipeLeft?.call();
          }
        }
        // Vertical swipe
        else {
          if (velocity.dy > threshold) {
            onSwipeDown?.call();
          } else if (velocity.dy < -threshold) {
            onSwipeUp?.call();
          }
        }
      },
      child: child,
    );
  }

  // Create long press detector
  Widget longPressDetector({
    required Widget child,
    required VoidCallback onLongPress,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: child,
    );
  }

  // Create double tap detector
  Widget doubleTapDetector({
    required Widget child,
    required VoidCallback onDoubleTap,
  }) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: child,
    );
  }

  // Create pinch to zoom detector
  Widget pinchToZoomDetector({
    required Widget child,
    required Function(double scale) onScaleChanged,
    double minScale = 0.5,
    double maxScale = 3.0,
  }) {
    return GestureDetector(
      onScaleUpdate: (details) {
        final scale = details.scale.clamp(minScale, maxScale);
        onScaleChanged(scale);
      },
      child: child,
    );
  }

  // Create custom swipe card widget
  Widget swipeCard({
    required Widget child,
    required VoidCallback onSwipeLeft,
    required VoidCallback onSwipeRight,
    Color leftSwipeColor = Colors.red,
    Color rightSwipeColor = Colors.green,
    IconData? leftSwipeIcon,
    IconData? rightSwipeIcon,
  }) {
    return SwipeCard(
      child: child,
      onSwipeLeft: onSwipeLeft,
      onSwipeRight: onSwipeRight,
      leftSwipeColor: leftSwipeColor,
      rightSwipeColor: rightSwipeColor,
      leftSwipeIcon: leftSwipeIcon,
      rightSwipeIcon: rightSwipeIcon,
    );
  }

  // Create pull to refresh detector
  Widget pullToRefreshDetector({
    required Widget child,
    required Future<void> Function() onRefresh,
    double displacementThreshold = 100.0,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      displacement: displacementThreshold,
      child: child,
    );
  }

  // Create slide to delete widget
  Widget slideToDelete({
    required Widget child,
    required VoidCallback onDelete,
    Color deleteColor = Colors.red,
    IconData deleteIcon = Icons.delete,
    double deleteThreshold = 0.6,
  }) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => onDelete(),
      background: Container(
        color: deleteColor,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(
          deleteIcon,
          color: Colors.white,
          size: 24,
        ),
      ),
      child: child,
    );
  }

  // Create expandable card with gesture
  Widget expandableCard({
    required Widget title,
    required Widget content,
    bool initiallyExpanded = false,
    Duration animationDuration = const Duration(milliseconds: 300),
  }) {
    return ExpandableCard(
      title: title,
      content: content,
      initiallyExpanded: initiallyExpanded,
      animationDuration: animationDuration,
    );
  }

  // Create draggable item
  Widget draggableItem({
    required Widget child,
    required Widget feedback,
    required Function(DragTargetDetails) onDragEnd,
    Object? data,
  }) {
    return Draggable<Object>(
      data: data ?? child,
      feedback: feedback,
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: child,
      ),
      onDragEnd: onDragEnd,
      child: child,
    );
  }

  // Create drag target
  Widget dragTarget<T>({
    required Widget child,
    required Function(T) onAccept,
    Function(T)? onWillAccept,
    Function(T)? onLeave,
  }) {
    return DragTarget<T>(
      onWillAccept: onWillAccept,
      onAccept: onAccept,
      onLeave: onLeave,
      builder: (context, candidateData, rejectedData) => child,
    );
  }

  // Create custom gesture detector with haptic feedback
  Widget hapticGestureDetector({
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    VoidCallback? onDoubleTap,
    HapticType hapticType = HapticType.light,
  }) {
    return GestureDetector(
      onTap: () {
        HapticService.instance.trigger(hapticType);
        onTap?.call();
      },
      onLongPress: () {
        HapticService.instance.trigger(HapticType.heavy);
        onLongPress?.call();
      },
      onDoubleTap: () {
        HapticService.instance.trigger(HapticType.medium);
        onDoubleTap?.call();
      },
      child: child,
    );
  }

  // Create ripple effect wrapper
  Widget rippleEffect({
    required Widget child,
    VoidCallback? onTap,
    Color? rippleColor,
    BorderRadius? borderRadius,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: rippleColor,
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }

  // Create slide panel
  Widget slidePanel({
    required Widget panel,
    required Widget body,
    SlideDirection direction = SlideDirection.up,
    double panelSize = 0.5,
    bool draggable = true,
  }) {
    return SlidePanel(
      panel: panel,
      body: body,
      direction: direction,
      panelSize: panelSize,
      draggable: draggable,
    );
  }
}

// Custom widgets for advanced gestures

class SwipeCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final Color leftSwipeColor;
  final Color rightSwipeColor;
  final IconData? leftSwipeIcon;
  final IconData? rightSwipeIcon;

  const SwipeCard({
    Key? key,
    required this.child,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    this.leftSwipeColor = Colors.red,
    this.rightSwipeColor = Colors.green,
    this.leftSwipeIcon,
    this.rightSwipeIcon,
  }) : super(key: key);

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        _controller.value = details.delta.dx / 300;
      },
      onPanEnd: (details) {
        if (_controller.value > 0.3) {
          widget.onSwipeRight();
        } else if (_controller.value < -0.3) {
          widget.onSwipeLeft();
        }
        _controller.animateTo(0);
      },
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Stack(
            children: [
              // Left swipe indicator
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.leftSwipeColor.withOpacity(_animation.value.abs()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: widget.leftSwipeIcon != null
                      ? Icon(
                          widget.leftSwipeIcon,
                          color: Colors.white,
                          size: 48,
                        )
                      : null,
                ),
              ),
              // Right swipe indicator
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.rightSwipeColor.withOpacity(_animation.value.abs()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerRight,
                  child: widget.rightSwipeIcon != null
                      ? Icon(
                          widget.rightSwipeIcon,
                          color: Colors.white,
                          size: 48,
                        )
                      : null,
                ),
              ),
              // Card content
              Transform.translate(
                offset: Offset(_animation.value * 300, 0),
                child: widget.child,
              ),
            ],
          );
        },
      ),
    );
  }
}

class ExpandableCard extends StatefulWidget {
  final Widget title;
  final Widget content;
  final bool initiallyExpanded;
  final Duration animationDuration;

  const ExpandableCard({
    Key? key,
    required this.title,
    required this.content,
    this.initiallyExpanded = false,
    this.animationDuration = const Duration(milliseconds: 300),
  }) : super(key: key);

  @override
  State<ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    
    _isExpanded = widget.initiallyExpanded;
    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: widget.title),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: widget.animationDuration,
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: widget.animationDuration,
            curve: Curves.easeInOut,
            child: _isExpanded
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: widget.content,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class SlidePanel extends StatefulWidget {
  final Widget panel;
  final Widget body;
  final SlideDirection direction;
  final double panelSize;
  final bool draggable;

  const SlidePanel({
    Key? key,
    required this.panel,
    required this.body,
    this.direction = SlideDirection.up,
    this.panelSize = 0.5,
    this.draggable = true,
  }) : super(key: key);

  @override
  State<SlidePanel> createState() => _SlidePanelState();
}

class _SlidePanelState extends State<SlidePanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    Offset begin;
    switch (widget.direction) {
      case SlideDirection.up:
        begin = const Offset(0, 1);
        break;
      case SlideDirection.down:
        begin = const Offset(0, -1);
        break;
      case SlideDirection.left:
        begin = const Offset(1, 0);
        break;
      case SlideDirection.right:
        begin = const Offset(-1, 0);
        break;
    }
    
    _animation = Tween<Offset>(begin: begin, end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.body,
        GestureDetector(
          onTap: _toggle,
          child: SlideTransition(
            position: _animation,
            child: FractionallySizedBox(
              heightFactor: widget.panelSize,
              widthFactor: widget.direction == SlideDirection.left || 
                         widget.direction == SlideDirection.right 
                      ? widget.panelSize 
                      : 1.0,
              alignment: widget.direction == SlideDirection.up ||
                         widget.direction == SlideDirection.left
                      ? Alignment.bottomLeft
                      : Alignment.topRight,
              child: widget.panel,
            ),
          ),
        ),
      ],
    );
  }
}

// Haptic feedback service
class HapticService {
  static final HapticService instance = HapticService._init();
  HapticService._init();

  void trigger(HapticType type) {
    switch (type) {
      case HapticType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticType.selection:
        HapticFeedback.selectionClick();
        break;
    }
  }
}

enum HapticType {
  light,
  medium,
  heavy,
  selection,
}

enum SlideDirection {
  up,
  down,
  left,
  right,
}
