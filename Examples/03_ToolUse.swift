/// Example: Automatic tool execution
///
/// Demonstrates:
///   - Defining a custom `Tool`
///   - Using predefined `CalendarTool` and `LocationTool`
///   - Letting `AIClient` handle the tool-execution loop automatically

import AIProviderKit
import ClaudeProvider

// MARK: - Custom tool

let productSearchTool = Tool(
    name: "search_products",
    description: "Searches the product catalog and returns matching items.",
    inputSchema: .object(
        properties: [
            "query":    .string(description: "Search query."),
            "maxResults": .integer(description: "Max number of results. Default: 5.")
        ],
        required: ["query"]
    )
) { input async throws in
    let query = input["query"]?.stringValue ?? ""
    let max   = input["maxResults"]?.intValue ?? 5

    // Replace with real data source:
    let fakeResults = (1...max).map { i -> JSONValue in
        .object(["id": .string("prod_\(i)"), "name": .string("\(query) item \(i)"), "price": .double(9.99 * Double(i))])
    }
    return .array(fakeResults)
}

// MARK: - Setup with tools

let client: AIClient = {
    let provider = ClaudeProvider(
        authorization: APIKeyAuthorization(apiKey: "sk-ant-YOUR_KEY_HERE")
    )
    return AIClient(provider: provider)
}()

func runWithTools() async throws {
    await client.toolRegistry.register(productSearchTool)

    // Predefined device tools:
    await client.toolRegistry.register(LocationTool.make())
    await client.toolRegistry.registerAll(CalendarTool.self)
    await client.toolRegistry.registerAll(RemindersTool.self)

    let request = try AIRequestBuilder()
        .model(.claudeSonnet4)
        .tools(await client.toolRegistry.allTools)  // pass all registered tools
        .addMessage(.user(text: "Find me up to 3 'Swift book' products."))
        .build()

    // AIClient automatically:
    //  1. Sends the request
    //  2. Detects stopReason == .toolUse
    //  3. Executes the tool handler(s) in parallel
    //  4. Sends a follow-up with the results
    //  5. Returns the final AIResponse
    let response = try await client.send(request)
    print(response.text)
}
