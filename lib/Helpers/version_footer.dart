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
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('Version: $_version+$_buildNumber'),
      ),
    );
  }
}
