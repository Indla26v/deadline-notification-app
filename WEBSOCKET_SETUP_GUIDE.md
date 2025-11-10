# WebSocket Backend Setup Guide

## Overview
This guide helps you set up a backend service to enable real-time email notifications in the Bell app.

## Architecture
```
Gmail → Cloud Pub/Sub → Your Backend → WebSocket → Flutter App
```

## Prerequisites
- Google Cloud Platform account
- Node.js (v16+) or Python (3.8+)
- Gmail API enabled
- Cloud Pub/Sub API enabled

## Step 1: Google Cloud Setup

### Enable APIs
```bash
gcloud services enable gmail.googleapis.com
gcloud services enable pubsub.googleapis.com
```

### Create Pub/Sub Topic
```bash
gcloud pubsub topics create gmail-notifications
gcloud pubsub subscriptions create gmail-sub --topic=gmail-notifications
```

### Grant Gmail Permissions
```bash
# Get the Pub/Sub service account
gcloud pubsub topics get-iam-policy gmail-notifications

# Grant publish permission to Gmail
gcloud pubsub topics add-iam-policy-binding gmail-notifications \
  --member=serviceAccount:gmail-api-push@system.gserviceaccount.com \
  --role=roles/pubsub.publisher
```

## Step 2: Backend Service (Node.js Example)

### Install Dependencies
```bash
npm init -y
npm install ws googleapis @google-cloud/pubsub dotenv
```

### Create `server.js`
```javascript
const WebSocket = require('ws');
const {google} = require('googleapis');
const {PubSub} = require('@google-cloud/pubsub');
require('dotenv').config();

// Initialize
const wss = new WebSocket.Server({ port: 8080 });
const pubsub = new PubSub();
const clients = new Map(); // Map<userEmail, WebSocket>

// Gmail watch setup
async function setupGmailWatch(userEmail, oauth2Client) {
  try {
    const gmail = google.gmail({version: 'v1', auth: oauth2Client});
    
    const watchResponse = await gmail.users.watch({
      userId: 'me',
      requestBody: {
        topicName: `projects/${process.env.GCP_PROJECT_ID}/topics/gmail-notifications`,
        labelIds: ['INBOX'],
        labelFilterAction: 'include'
      }
    });
    
    console.log(`Gmail watch set up for ${userEmail}:`, watchResponse.data);
    return watchResponse.data;
  } catch (error) {
    console.error(`Error setting up watch for ${userEmail}:`, error);
    throw error;
  }
}

// WebSocket connection handler
wss.on('connection', (ws) => {
  console.log('New WebSocket connection');
  
  ws.on('message', async (message) => {
    try {
      const data = JSON.parse(message);
      
      switch(data.type) {
        case 'auth':
          // Store client with email
          clients.set(data.email, ws);
          ws.userEmail = data.email;
          
          // Set up Gmail watch for this user
          const oauth2Client = await getOAuth2Client(data.email);
          await setupGmailWatch(data.email, oauth2Client);
          
          ws.send(JSON.stringify({
            type: 'auth_success',
            message: 'Connected and watching Gmail'
          }));
          break;
          
        case 'ping':
          ws.send(JSON.stringify({
            type: 'pong',
            timestamp: new Date().toISOString()
          }));
          break;
          
        case 'subscribe':
          console.log(`${data.email} subscribed to ${data.event}`);
          break;
      }
    } catch (error) {
      console.error('Error handling message:', error);
      ws.send(JSON.stringify({
        type: 'error',
        message: error.message
      }));
    }
  });
  
  ws.on('close', () => {
    if (ws.userEmail) {
      clients.delete(ws.userEmail);
      console.log(`Client disconnected: ${ws.userEmail}`);
    }
  });
});

// Listen to Pub/Sub notifications
const subscription = pubsub.subscription('gmail-sub');

subscription.on('message', async (message) => {
  try {
    const data = JSON.parse(message.data.toString());
    console.log('Pub/Sub notification:', data);
    
    // Get user email from history
    const userEmail = data.emailAddress;
    
    // Fetch new email details
    const oauth2Client = await getOAuth2Client(userEmail);
    const gmail = google.gmail({version: 'v1', auth: oauth2Client});
    
    const history = await gmail.users.history.list({
      userId: 'me',
      startHistoryId: data.historyId
    });
    
    // Check for new messages
    if (history.data.history) {
      for (const historyItem of history.data.history) {
        if (historyItem.messagesAdded) {
          for (const added of historyItem.messagesAdded) {
            const messageId = added.message.id;
            
            // Get message details
            const messageDetails = await gmail.users.messages.get({
              userId: 'me',
              id: messageId,
              format: 'full'
            });
            
            const headers = messageDetails.data.payload.headers;
            const subject = headers.find(h => h.name === 'Subject')?.value || 'No Subject';
            const from = headers.find(h => h.name === 'From')?.value || 'Unknown';
            
            // Send to connected client
            const ws = clients.get(userEmail);
            if (ws && ws.readyState === WebSocket.OPEN) {
              ws.send(JSON.stringify({
                type: 'new_email',
                subject: subject,
                from: from,
                messageId: messageId,
                timestamp: new Date().toISOString()
              }));
            }
          }
        }
      }
    }
    
    message.ack();
  } catch (error) {
    console.error('Error processing Pub/Sub message:', error);
    message.nack();
  }
});

subscription.on('error', (error) => {
  console.error('Pub/Sub subscription error:', error);
});

// Helper function to get OAuth2 client (implement based on your auth strategy)
async function getOAuth2Client(userEmail) {
  // Implement OAuth2 token retrieval from your database
  // This should return a configured OAuth2 client
  const oauth2Client = new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    process.env.GOOGLE_REDIRECT_URI
  );
  
  // Set credentials from your database
  const tokens = await getStoredTokens(userEmail);
  oauth2Client.setCredentials(tokens);
  
  return oauth2Client;
}

async function getStoredTokens(userEmail) {
  // Implement database lookup for stored tokens
  // Return: { access_token, refresh_token, ... }
  throw new Error('Not implemented');
}

console.log('WebSocket server running on ws://localhost:8080');
console.log('Listening to Gmail notifications via Pub/Sub...');
```

### Create `.env`
```env
GCP_PROJECT_ID=your-project-id
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
GOOGLE_REDIRECT_URI=http://localhost:3000/auth/callback
```

### Run
```bash
node server.js
```

## Step 3: Flutter App Configuration

Update WebSocket URL in `lib/services/websocket_service.dart`:

```dart
// Change this line:
final wsUrl = 'wss://your-backend-service.com/ws?email=$userEmail';

// To your actual server URL:
final wsUrl = 'ws://YOUR_SERVER_IP:8080/ws?email=$userEmail';
```

## Step 4: Deploy to Production

### Option A: Google Cloud Run
```bash
# Create Dockerfile
cat > Dockerfile << EOF
FROM node:16-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY . .
EXPOSE 8080
CMD ["node", "server.js"]
EOF

# Deploy
gcloud builds submit --tag gcr.io/YOUR_PROJECT/bell-websocket
gcloud run deploy bell-websocket \
  --image gcr.io/YOUR_PROJECT/bell-websocket \
  --platform managed \
  --allow-unauthenticated
```

### Option B: Heroku
```bash
# Install Heroku CLI
heroku create bell-websocket-app
git push heroku main
```

### Option C: AWS Lambda + API Gateway (WebSocket)
Use AWS API Gateway WebSocket support with Lambda functions.

## Testing

### Test WebSocket Connection
```bash
# Install wscat
npm install -g wscat

# Connect
wscat -c ws://localhost:8080

# Send auth message
{"type":"auth","email":"yourEmail@gmail.com","timestamp":"2025-11-10T15:00:00Z"}

# You should receive auth_success
```

### Test Gmail Notifications
1. Send yourself an email
2. Check WebSocket server logs
3. Verify Pub/Sub message received
4. Confirm Flutter app shows notification

## Troubleshooting

### Issue: Watch expires after 7 days
**Solution**: Set up a cron job to renew watches:
```javascript
// Renew every 6 days
setInterval(async () => {
  for (const [email, ws] of clients.entries()) {
    const oauth2Client = await getOAuth2Client(email);
    await setupGmailWatch(email, oauth2Client);
  }
}, 6 * 24 * 60 * 60 * 1000);
```

### Issue: Token expiration
**Solution**: Implement token refresh:
```javascript
oauth2Client.on('tokens', (tokens) => {
  // Store new tokens in database
  storeTokens(userEmail, tokens);
});
```

### Issue: WebSocket disconnects
**Solution**: Implement reconnection in Flutter (already done in code)

## Security Considerations

1. **Use WSS (TLS)**: Always use `wss://` in production
2. **Authenticate Connections**: Verify user tokens before setting up watches
3. **Rate Limiting**: Implement rate limits to prevent abuse
4. **Store Tokens Securely**: Use encryption for stored OAuth tokens
5. **CORS**: Configure proper CORS headers if needed

## Alternative: Simplified Polling

If WebSocket setup is too complex, use HTTP polling instead:

```dart
// In your Flutter app
Timer.periodic(Duration(minutes: 5), (timer) async {
  final newEmails = await _gmailService.fetchEmails(_client!);
  if (newEmails.isNotEmpty) {
    // Show notification
  }
});
```

## Cost Estimation (Google Cloud)

- Pub/Sub: ~$0.40 per million operations
- Cloud Run: ~$0.00002400 per GB-second
- For 1000 users with 10 emails/day each:
  - ~$12/month for Pub/Sub
  - ~$5/month for Cloud Run

## Resources

- [Gmail Push Notifications](https://developers.google.com/gmail/api/guides/push)
- [Google Cloud Pub/Sub](https://cloud.google.com/pubsub/docs)
- [WebSocket RFC](https://tools.ietf.org/html/rfc6455)

---

**Note**: WebSocket is optional. The app works perfectly with manual refresh if you don't want to set up a backend!
