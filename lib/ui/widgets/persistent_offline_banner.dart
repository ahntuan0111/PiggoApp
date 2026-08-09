import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:appintern/core/services/network_service.dart';
import 'dart:async';

class PersistentOfflineBanner extends StatefulWidget {
  const PersistentOfflineBanner({super.key});

  @override
  State<PersistentOfflineBanner> createState() =>
      _PersistentOfflineBannerState();
}

class _PersistentOfflineBannerState extends State<PersistentOfflineBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _sizeAnimation;
  final NetworkService _networkService = Get.find<NetworkService>();

  bool _isOffline = false;
  bool _isReconnecting = false;
  Timer? _hideTimer;
  late StreamSubscription _networkSub;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _sizeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _isOffline = _networkService.isOffline.value;
    if (_isOffline) {
      _controller.value = 1.0;
    }

    // Listen to network changes
    _networkSub = _networkService.isOffline.listen((isOffline) {
      if (isOffline) {
        // Mất mạng
        _hideTimer?.cancel();
        setState(() {
          _isOffline = true;
          _isReconnecting = false;
        });
        _controller.forward();
      } else {
        // Có mạng lại
        if (_isOffline) {
          setState(() {
            _isOffline = false;
            _isReconnecting = true;
          });
          // Hiển thị thông báo "Đã kết nối lại" trong 2 giây rồi ẩn
          _hideTimer?.cancel();
          _hideTimer = Timer(const Duration(seconds: 2), () {
            _controller.reverse().then((_) {
              if (mounted) {
                setState(() {
                  _isReconnecting = false;
                });
              }
            });
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _networkSub.cancel();
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _sizeAnimation,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          height: 32.h,
          color: _isReconnecting ? Colors.green : Colors.orange,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isReconnecting ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                color: Colors.white,
                size: 14.sp,
              ),
              SizedBox(width: 6.w),
              Flexible(
                child: Text(
                  _isReconnecting ? "Đã kết nối lại" : "Đang ngoại tuyến",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
