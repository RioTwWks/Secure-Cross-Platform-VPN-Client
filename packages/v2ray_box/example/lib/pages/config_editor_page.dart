import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:v2ray_box/v2ray_box.dart';

class ConfigEditorPage extends StatefulWidget {
  final V2rayBox v2rayBox;
  final String configJson;
  final String configName;

  const ConfigEditorPage({
    super.key,
    required this.v2rayBox,
    required this.configJson,
    required this.configName,
  });

  @override
  State<ConfigEditorPage> createState() => _ConfigEditorPageState();
}

class _ConfigEditorPageState extends State<ConfigEditorPage> {
  late TextEditingController _ctrl;
  bool _isValid = true;
  String _validationMsg = '';
  bool _isValidating = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _formatJson(widget.configJson));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _formatJson(String json) {
    try {
      final obj = jsonDecode(json);
      return const JsonEncoder.withIndent('  ').convert(obj);
    } catch (_) {
      return json;
    }
  }

  Future<void> _validate() async {
    setState(() => _isValidating = true);
    try {
      String compactJson;
      try {
        compactJson = jsonEncode(jsonDecode(_ctrl.text));
      } catch (e) {
        setState(() {
          _isValid = false;
          _validationMsg = 'Invalid JSON syntax: $e';
          _isValidating = false;
        });
        return;
      }

      final result = await widget.v2rayBox.checkConfigJson(compactJson);
      setState(() {
        _isValid = result.isEmpty;
        _validationMsg = result.isEmpty ? 'Config is valid' : result;
        _isValidating = false;
      });
    } catch (e) {
      setState(() {
        _isValid = false;
        _validationMsg = 'Validation error: $e';
        _isValidating = false;
      });
    }
  }

  Future<void> _connectWithJson() async {
    setState(() => _isConnecting = true);
    try {
      String compactJson;
      try {
        compactJson = jsonEncode(jsonDecode(_ctrl.text));
      } catch (e) {
        _snack('Invalid JSON: $e');
        setState(() => _isConnecting = false);
        return;
      }

      final ok = await widget.v2rayBox.connectWithJson(compactJson, name: widget.configName);
      if (ok) {
        _snack('Connected with custom config');
        if (mounted) Navigator.pop(context);
      } else {
        _snack('Failed to connect');
      }
    } catch (e) {
      _snack('Error: $e');
    }
    if (mounted) setState(() => _isConnecting = false);
  }

  void _copyJson() {
    Clipboard.setData(ClipboardData(text: _ctrl.text));
    _snack('JSON copied');
  }

  void _formatText() {
    final formatted = _formatJson(_ctrl.text);
    _ctrl.text = formatted;
    _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: formatted.length));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2D2D44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.configName, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(icon: const Icon(Icons.format_align_left), onPressed: _formatText, tooltip: 'Format JSON'),
          IconButton(icon: const Icon(Icons.copy), onPressed: _copyJson, tooltip: 'Copy'),
          IconButton(
            icon: _isValidating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_circle_outline),
            onPressed: _isValidating ? null : _validate,
            tooltip: 'Validate',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_validationMsg.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _isValid ? const Color(0xFF2ED573).withOpacity(0.2) : const Color(0xFFE74C3C).withOpacity(0.2),
              child: Row(
                children: [
                  Icon(
                    _isValid ? Icons.check_circle : Icons.error,
                    color: _isValid ? const Color(0xFF2ED573) : const Color(0xFFE74C3C),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _validationMsg,
                      style: TextStyle(
                        color: _isValid ? const Color(0xFF2ED573) : const Color(0xFFE74C3C),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.5),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(8),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _isConnecting ? null : _connectWithJson,
            icon: _isConnecting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.play_arrow),
            label: Text(_isConnecting ? 'Connecting...' : 'Connect with this config'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }
}
