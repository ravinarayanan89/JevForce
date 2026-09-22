@IsTest
public class JevHttpMock implements HttpCalloutMock {
    public static HttpRequest lastRequest;
    private Integer statusCode;
    private String responseBody;

    public JevHttpMock(Integer statusCode, String responseBody) {
        this.statusCode = statusCode;
        this.responseBody = responseBody;
    }

    public HttpResponse respond(HttpRequest request) {
        lastRequest = request;
        HttpResponse response = new HttpResponse();
        response.setStatusCode(statusCode);
        response.setBody(responseBody);
        response.setHeader('Content-Type', 'application/json');
        return response;
    }
}
