enum LocalizedDeviceCount {
    static func usb(_ count: Int) -> String {
        count == 1 ? R.L.Status_DEVICE_COUNT_ONE : R.L.Status_DEVICE_COUNT(count)
    }

    static func serial(_ count: Int) -> String {
        count == 1 ? R.L.Status_SERIAL_COUNT_ONE : R.L.Status_SERIAL_COUNT(count)
    }
}
