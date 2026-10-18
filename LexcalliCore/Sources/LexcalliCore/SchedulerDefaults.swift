import FSRS

public enum SchedulerDefaults {
    /// FSRS-6 parameters with the canonical default weights.
    ///
    /// swift-fsrs falls back to FSRS-5 when `w` is omitted, so the 21-weight vector is passed explicitly.
    public static let parameters = FSRSParameters(w: FSRSDefaults.defaultWv6)
}
