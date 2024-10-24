const WebSocket = require('ws');
const os = require('os');

// Function to get the local IP address
function getLocalIPAddress() {
  const networkInterfaces = os.networkInterfaces();
  for (const interfaceName in networkInterfaces) {
    for (const net of networkInterfaces[interfaceName]) {
      // Check if the address is an IPv4 address and is not a loopback address
      if (net.family === 'IPv4' && !net.internal) {
        return net.address;
      }
    }
  }
  return '127.0.0.1'; // Fallback to localhost if no external IP is found
}

// Get local IP address
const localIP = getLocalIPAddress();
const port = 8080;

// Create WebSocket server
const wss = new WebSocket.Server({ host: '0.0.0.0', port });

console.log(`WebSocket server started on ws://${localIP}:${port}`);
console.log(`You can connect from other machines using: ws://${localIP}:${port}`);

// Log when a new connection is established
wss.on('connection', ws => {
  console.log('New client connected');
  
  // Send a welcome message to the new client
  ws.send(JSON.stringify({ event: 'message', data: 'Connection Established' }));
  console.log('Welcome message sent to new client');

  // Log when a message is received from a client
  ws.on('message', message => {
    console.log(`Received message from client:\n`);
    console.log(message);
    
    // Broadcast the message to all clients, except the sender
    wss.clients.forEach(client => {
      if (client !== ws && client.readyState === WebSocket.OPEN) {
        console.log('Broadcasting message to other clients');
        client.send(message);
      }
    });
  });

  // Log if there is an error with a client connection
  ws.on('error', error => {
    console.error(`Error occurred with client: ${error.message}`);
  });

  // Log when a client connection is closed
  ws.on('close', () => {
    console.log('Client disconnected');
  });
});

// Log the total number of connected clients
wss.on('connection', () => {
  console.log(`Total connected clients: ${wss.clients.size}`);
});

// Log when the server is about to shut down
process.on('SIGINT', () => {
  console.log('Server shutting down...');
  wss.close(() => {
    console.log('WebSocket server closed');
    process.exit(0);
  });
});
