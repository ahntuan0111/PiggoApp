enum UIState {
  initial, // Chưa load lần nào (first launch)
  loading, // Đang fetch dữ liệu
  success, // Dữ liệu hiển thị từ Server thành công
  offlineCached, // Dữ liệu hiển thị từ Cache Local (không có mạng)
  empty, // Fetch thành công nhưng danh sách rỗng
  error, // Xảy ra lỗi không thể tự hồi phục
}
