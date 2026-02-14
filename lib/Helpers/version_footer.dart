import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionFooter extends StatefulWidget {
  const VersionFooter({super.key});

  @override
  _VersionFooterState createState() => _VersionFooterState();
}

class _VersionFooterState extends State<VersionFooter> {
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Text(
        'v$_version ($_buildNumber)',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary.withOpacity(0.4),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
