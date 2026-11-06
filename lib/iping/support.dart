import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../ui/ui.dart';

const _supportQrUrl = 'https://video.iping.my/images/wechat.png';

Future<void> showIpingSupport(BuildContext context) {
  return showFloatingDialog<void>(
    context: context,
    child: const IpingSupportDialog(),
  );
}

Future<Uint8List> _loadImage() async {
  final client = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  try {
    final response = await client.get<List<int>>(
      _supportQrUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('Empty support QR image');
    }
    return Uint8List.fromList(bytes);
  } finally {
    client.close();
  }
}

Future<void> _saveImage(Uint8List bytes) async {
  await FilePicker.saveFile(
    fileName: 'iping-support.png',
    bytes: bytes,
    mimeType: 'image/png',
  );
}

class IpingSupportDialog extends StatefulWidget {
  const IpingSupportDialog({
    super.key,
    this.load = _loadImage,
    this.save = _saveImage,
  });

  final Future<Uint8List> Function() load;
  final Future<void> Function(Uint8List bytes) save;

  @override
  State<IpingSupportDialog> createState() => _IpingSupportDialogState();
}

class _IpingSupportDialogState extends State<IpingSupportDialog> {
  late Future<Uint8List> _image;
  var _saving = false;
  var _saveFailed = false;

  @override
  void initState() {
    super.initState();
    _image = widget.load();
  }

  Future<void> _save(Uint8List bytes) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await widget.save(bytes);
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<Uint8List>(
      future: _image,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return CommonDialog(
          title: l.ipingContactSupport,
          contentMaxWidth: 280,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.close),
            ),
            TextButton(
              onPressed: bytes == null || _saving ? null : () => _save(bytes),
              child: _saving
                  ? CommonCircleLoading(
                      size: 20,
                      semanticLabel: l.ipingSaveImage,
                    )
                  : Text(l.ipingSaveImage),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRSuperellipse(
                borderRadius: AppRadius.md,
                child: ColoredBox(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: bytes != null
                        ? Image.memory(
                            bytes,
                            fit: BoxFit.contain,
                            semanticLabel: l.ipingContactSupport,
                          )
                        : AspectRatio(
                            aspectRatio: 1,
                            child: Center(
                              child: snapshot.hasError
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          l.ipingSupportQrFailed,
                                          textAlign: TextAlign.center,
                                        ),
                                        TextButton(
                                          onPressed: () => setState(() {
                                            _image = widget.load();
                                          }),
                                          child: Text(l.retry),
                                        ),
                                      ],
                                    )
                                  : const CommonCircleLoading(),
                            ),
                          ),
                  ),
                ),
              ),
              if (_saveFailed)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    l.ipingSaveImageFailed,
                    style: TextStyle(color: context.colorScheme.error),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
