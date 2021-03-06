// Copyright (c) 2018 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/config;
import ballerina/http;
import ballerina/log;
import wso2/gsheets4;
import wso2/gmail;

# A valid access token with gmail and google sheets access.
string accessToken = config:getAsString("ACCESS_TOKEN");

# The client ID for your application.
string clientId = config:getAsString("CLIENT_ID");

# The client secret for your application.
string clientSecret = config:getAsString("CLIENT_SECRET");

# A valid refreshToken with gmail and google sheets access.
string refreshToken = config:getAsString("REFRESH_TOKEN");

# Spreadsheet id of the reference google sheet.
string spreadsheetId = config:getAsString("SPREADSHEET_ID");

# Sheet name of the reference googlle sheet.
string sheetName = config:getAsString("SHEET_NAME");

# Sender email address.
string senderEmail = config:getAsString("SENDER");

# The user's email address.
string userId = config:getAsString("USER_ID");

# Google Sheets client endpoint declaration with http client configurations.
gsheets4:Client spreadsheetClient = new({
    clientConfig: {
        auth: {
            scheme: http:OAUTH2,
            config: {
                grantType: http:DIRECT_TOKEN,
                config: {
                    accessToken: accessToken,
                    refreshConfig: {
                        clientId: clientId,
                        clientSecret: clientSecret,
                        refreshUrl: gsheets4:REFRESH_URL,
                        refreshToken: refreshToken
                    }
                }
            }
        }
    }
});

# GMail client endpoint declaration with oAuth2 client configurations.
gmail:Client gmailClient = new({
    clientConfig: {
        auth: {
            scheme: http:OAUTH2,
            config: {
                grantType: http:DIRECT_TOKEN,
                config: {
                    accessToken: accessToken,
                    refreshConfig: {
                        refreshUrl: gmail:REFRESH_URL,
                        refreshToken: refreshToken,
                        clientId: clientId,
                        clientSecret: clientSecret
                    }
                }
            }
        }
    }
});

# Main function to run the integration system.
public function main() {
    log:printDebug("GMail-Spreadsheet Integration -> Sending notification to customers");
    boolean result = sendNotification();
    if (result) {
        log:printDebug("GMail-Spreadsheet Integration -> Sending notification to customers successfully completed!");
    } else {
        log:printDebug("GMail-Spreadsheet Integration -> Sending notification to customers failed!");
    }
}

# Returns an indication of the status of the sending notification to the customers.
#
# + return - State of whether the process of sending notification is success or not
function sendNotification() returns boolean {
    //Retrieve the customer details from spreadsheet.
    var customerDetails = getCustomerDetailsFromGSheet();
    if (customerDetails is error) {
        log:printError("Failed to retrieve customer details from GSheet", err = customerDetails);
        return false;
    } else {
        int i = 0;
        boolean isSuccess = false;
        //Iterate through each customer details and send customized email.
        foreach var value in customerDetails {
            //Skip the first row as it contains header values.
            if (i > 0) {
                string productName = value[0];
                string CutomerName = value[1];
                string customerEmail = value[2];
                string subject = "Thank You for Downloading " + productName;
                isSuccess = sendMail(customerEmail, subject, getCustomEmailTemplate(CutomerName, productName));
                if (!isSuccess) {
                    break;
                }
            }
            i += 1;
        }
        return isSuccess;
    }
}

# Retrieves customer details from the spreadsheet statistics.
#
# + return - Two dimensional string array of spreadsheet cell values.
function getCustomerDetailsFromGSheet() returns string[][]|error {
    //Read all the values from the sheet.
    string[][] values = check spreadsheetClient->getSheetValues(spreadsheetId, sheetName);
    log:printInfo("Retrieved customer details from spreadsheet id: " + spreadsheetId + "; sheet name: "
            + sheetName);
    return values;
}

# Get the customized email template.
#
# + customerName - Name of the customer.
# + productName - Name of the product which the customer has downloaded.
# + return - String customized email message.
function getCustomEmailTemplate(string customerName, string productName) returns string {
    string emailTemplate = "<h2> Hi " + customerName + " </h2>";
    emailTemplate = emailTemplate + "<h3> Thank you for downloading the product " + productName + " ! </h3>";
    emailTemplate = emailTemplate + "<p> If you still have questions regarding " + productName +
        ", please contact us and we will get in touch with you right away ! </p> ";
    return emailTemplate;
}

# Send email with the given message body to the specified recipient for dowloading the specified product and return the
# indication of sending is succss or not.
#
# + customerEmail - Recipient's email address.
# + subject - Subject of the email.
# + messageBody - Email message body to send.
# + return - The status of sending email success or not
function sendMail(string customerEmail, string subject, string messageBody) returns boolean {
    //Create html message
    gmail:MessageRequest messageRequest = {};
    messageRequest.recipient = customerEmail;
    messageRequest.sender = senderEmail;
    messageRequest.subject = subject;
    messageRequest.messageBody = messageBody;
    messageRequest.contentType = gmail:TEXT_HTML;

    //Send mail
    var sendMessageResponse = gmailClient->sendMessage(userId, untaint messageRequest);
    string messageId;
    string threadId;
    if (sendMessageResponse is (string, string)) {
        (messageId, threadId) = sendMessageResponse;
        log:printInfo("Sent email to " + customerEmail + " with message Id: " + messageId +
            " and thread Id:" + threadId);
        return true;
    } else {
        log:printInfo(<string>sendMessageResponse.detail().message);
        return false;
    }
}
