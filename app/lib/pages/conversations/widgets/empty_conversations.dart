import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class EmptyConversationsWidget extends StatefulWidget {
  final bool isStarredFilterActive;
  final bool isShortConversationsFilterActive;

  const EmptyConversationsWidget({
    super.key,
    this.isStarredFilterActive = false,
    this.isShortConversationsFilterActive = false,
  });

  @override
  State<EmptyConversationsWidget> createState() => _EmptyConversationsWidgetState();
}

class _EmptyConversationsWidgetState extends State<EmptyConversationsWidget> {
  @override
  Widget build(BuildContext context) {
    if (widget.isStarredFilterActive) {
      return Padding(
        padding: const EdgeInsets.only(top: 80.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const FaIcon(
                FontAwesomeIcons.star,
                color: Colors.amber,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No starred conversations yet.',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'To star a conversation, open it and tap the star icon in the header.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    if (widget.isShortConversationsFilterActive) {
      return Padding(
        padding: const EdgeInsets.only(top: 80.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const FaIcon(
                FontAwesomeIcons.clock,
                color: Colors.deepPurple,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No short conversations yet.',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Short conversations under 60 seconds will appear here.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.only(top: 120.0),
      child: Text(
        'No conversations yet.',
        style: TextStyle(color: Colors.grey, fontSize: 16),
      ),
    );
  }
}
