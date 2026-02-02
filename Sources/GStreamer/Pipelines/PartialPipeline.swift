public struct PartialPipeline<Element: Sendable>: Sendable {
    internal var pipeline: String
    internal var sinkName: String?
    
    init(pipeline: String, sinkName: String? = nil) {
        self.pipeline = pipeline
        self.sinkName = sinkName
    }
}