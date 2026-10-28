// Agora Signaling Web 2.2.3 is bundled locally in agora-rtm-bundle.js.
const agoraChatClients = new Map();
let nextAgoraChatId = 1;

window.agoraChatConnect = async (appId, userId, token, channelName, onMessage) => {
  const client = new window.AgoraChatSDK.RTM(appId, userId);
  client.addEventListener('message', (event) => {
    if (event.channelName === channelName) {
      onMessage(String(event.publisher || ''), String(event.message || ''));
    }
  });
  try {
    await client.login({token});
    await client.subscribe(channelName);
  } catch (error) {
    try { await client.logout(); } catch (_) {}
    throw error;
  }
  const id = nextAgoraChatId++;
  agoraChatClients.set(id, {client, channelName});
  return id;
};

window.agoraChatSend = async (id, message) => {
  const entry = agoraChatClients.get(id);
  if (!entry) throw new Error('Chat chưa kết nối.');
  await entry.client.publish(entry.channelName, message, {channelType: 'MESSAGE'});
};

window.agoraChatRenewToken = async (id, token) => {
  const entry = agoraChatClients.get(id);
  if (entry) await entry.client.renewToken(token);
};

window.agoraChatDisconnect = async (id) => {
  const entry = agoraChatClients.get(id);
  agoraChatClients.delete(id);
  if (!entry) return;
  try { await entry.client.unsubscribe(entry.channelName); } finally {
    await entry.client.logout();
  }
};
