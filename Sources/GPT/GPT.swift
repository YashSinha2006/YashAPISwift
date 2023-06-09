//
//  Copyright © 2023 Dennis Müller and all collaborators
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation
import Get
import Base
@_exported import GPTSwiftSharedTypes

/// A simple wrapper around the API for OpenAI's GPT.
public class GPT {

    private let client: APIClient
    private let apiKey: String
    private let apiClientRequestHandler: _APIClientRequestHandler
    private let defaultModel: GPTModel

    /// A variant of `GPT` that streams all the answers.
    ///
    /// This exposes the exact same methods as before, but it returns an `AsyncThrowingStream` that yields individual tokens as soon as they are generated by GPT.
    public let streamedAnswer: StreamedAnswer

    /// A simple wrapper around the API for OpenAI.
    /// - Parameter apiKey: The api key you can generate in your account page on OpenAI's website.
    /// - Parameter defaultModel: Sets the default model for all requests coming from this `GPT` instance.
    /// - Parameter urlSessionConfiguration: An optional URL session configuration object.
    public init(
        apiKey: String,
        defaultModel: GPTModel = .davinci,
        urlSessionConfiguration: URLSessionConfiguration? = nil
    ) {
        self.apiKey = apiKey
        self.apiClientRequestHandler = .init(apiKey: apiKey)
        self.defaultModel = defaultModel
        self.client = APIClient(baseURL: URL(string: API.base)) { [apiClientRequestHandler] configuration in
            configuration.delegate = apiClientRequestHandler
            if let urlSessionConfiguration {
                configuration.sessionConfiguration = urlSessionConfiguration
            }
        }
        self.streamedAnswer = .init(client: client, apiKey: apiKey, defaultModel: defaultModel)
    }

    /// Generates a completion for the given user prompt using the specified model or the default model.
    ///
    /// This method is a convenience method for the "Create completion" OpenAI API endpoint.
    ///
    /// - Parameter userPrompt: The prompt to complete.
    /// - Parameter model: The GPT model to use for generating the completion. Defaults to `.default`.
    ///
    /// - Returns: A `CompletionResponse` object containing the generated completion.
    /// - Throws: A `GPTSwiftError` if the request fails or the server returns an unauthorized status code.
    public func complete(
        _ userPrompt: String,
        model: GPTModel = .default
    ) async throws -> CompletionResponse {
        let usingModel = model is DefaultGPTModel ? defaultModel : model
        let request = Request<CompletionResponse>(
            path: API.v1Completion,
            method: .post,
            body: CompletionRequest(model: usingModel, prompt: userPrompt)
        )

        return try await send(request: request)
    }

    /// Generates a completion for the given `CompletionRequest`.
    ///
    /// This method provides full control over the completion request and corresponds to the "Create completion" OpenAI API endpoint.
    ///
    /// - Parameter completionRequest: A `CompletionRequest` object containing the details of the completion request.
    ///
    /// - Returns: A `CompletionResponse` object containing the generated completion.
    /// - Throws: A `GPTSwiftError` if the request fails or the server returns an unauthorized status code.
    public func complete(request completionRequest: CompletionRequest) async throws -> CompletionResponse {
        let request = Request<CompletionResponse>(
            path: API.v1Completion,
            method: .post,
            body: completionRequest
        )

        return try await send(request: request)
    }

    /// Turns a completion request into a curl prompt that you can paste into a terminal.
    ///
    /// This might be useful for debugging to experimenting.
    /// Taken from [Abhishek Maurya](https://gist.github.com/abhi21git/3dc611aab9e1cf5e5343ba4b58573596) and slightly adjusted.
    /// - Parameters:
    ///   - completionRequest: The request.
    ///   - pretty: An option to make the curl prompt pretty.
    ///   - formatOutput: An option that, if set, puts the response through `json_pp` to prettify the json object.
    /// - Returns: The curl prompt.
    public func curl(for completionRequest: CompletionRequest, pretty: Bool = true, formatOutput: Bool = true) async throws -> String {
        let request = Request(path: API.v1Completion, method: .post, body: completionRequest)
        var urlRequest = try await client.makeURLRequest(for: request)
        _addHeaders(to: &urlRequest, apiKey: apiKey)
        return urlRequest.curl(pretty: pretty, formatOutput: formatOutput)
    }

    /// Sends the request, catches all errors and replaces them with a `GPTSwiftError`. If successful, it returns the response value.
    /// - Parameter request: The request to send.
    /// - Returns: The response object, already decoded.
    private func send<Response: Codable>(request: Request<Response>) async throws -> Response {
        do {
            return try await client.send(request).value
        } catch {
            throw _errorToGPTSwiftError(error)
        }
    }
}
