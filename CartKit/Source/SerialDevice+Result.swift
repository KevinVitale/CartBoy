extension Result {
    func resultFrom<NewSuccess, Device: DeviceProfile>(_ command: (Success) -> Result<NewSuccess,Error>) -> Result<NewSuccess,Error> where Success: SerialDevice<Device> {
        do {
            let value = try self.get()
            return command(value)
        }
        catch {
            return .failure(error)
        }
    }
    
    func resultFrom<NewSuccess, Device: DeviceProfile, A>(_ command: (Success, A) -> Result<NewSuccess,Error>, _ a: A) -> Result<NewSuccess,Error> where Success: SerialDevice<Device> {
        do {
            let value = try self.get()
            return command(value, a)
        }
        catch {
            return .failure(error)
        }
    }
    
    func resultFrom<NewSuccess, Device: DeviceProfile, A, B>(_ command: (Success, A, B) -> Result<NewSuccess,Error>, _ a: A, _ b: B) -> Result<NewSuccess,Error> where Success: SerialDevice<Device> {
        do {
            let value = try self.get()
            return command(value, a, b)
        }
        catch {
            return .failure(error)
        }
    }
}
