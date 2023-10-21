extension String {
    var headUppercased: String {
        prefix(1).uppercased() + dropFirst()
    }
}
