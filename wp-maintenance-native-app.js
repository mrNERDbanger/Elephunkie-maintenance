// App.js - Main React Native App for iOS/macOS
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  TextInput,
  Alert,
  Modal,
  FlatList,
  RefreshControl,
  Platform,
  Linking,
  Share
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import NetInfo from '@react-native-community/netinfo';

const API_BASE_URL = 'https://connect.elephunkie.com';

const WPMaintenanceApp = () => {
  const [clients, setClients] = useState([]);
  const [serverStatus, setServerStatus] = useState('disconnected');
  const [serverUrl, setServerUrl] = useState('');
  const [cloudflareApiKey, setCloudflareApiKey] = useState('');
  const [cloudflareEmail, setCloudflareEmail] = useState('');
  const [cloudflareZoneId, setCloudflareZoneId] = useState('');
  const [showAddClient, setShowAddClient] = useState(false);
  const [showSettings, setShowSettings] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [newClient, setNewClient] = useState({
    name: '',
    domain: '',
    adminUrl: '',
    adminUser: '',
    adminPass: ''
  });

  useEffect(() => {
    initializeApp();
    startServer();
  }, []);

  const initializeApp = async () => {
    try {
      const storedClients = await AsyncStorage.getItem('clients');
      const storedSettings = await AsyncStorage.getItem('settings');
      
      if (storedClients) {
        setClients(JSON.parse(storedClients));
      }
      
      if (storedSettings) {
        const settings = JSON.parse(storedSettings);
        setCloudflareApiKey(settings.cloudflareApiKey || '');
        setCloudflareEmail(settings.cloudflareEmail || '');
        setCloudflareZoneId(settings.cloudflareZoneId || '');
      }
    } catch (error) {
      console.error('Error initializing app:', error);
    }
  };

  const startServer = async () => {
    try {
      // Get local IP address
      const networkState = await NetInfo.fetch();
      const localIP = await getLocalIPAddress();
      const port = 3001;
      const serverUrl = `http://${localIP}:${port}`;
      
      setServerUrl(serverUrl);
      
      // Start the Express server
      await startExpressServer(port);
      
      // Configure Cloudflare DNS
      if (cloudflareApiKey) {
        await configureCloudflareDNS(localIP);
      }
      
      setServerStatus('connected');
    } catch (error) {
      console.error('Error starting server:', error);
      setServerStatus('error');
    }
  };

  const getLocalIPAddress = async () => {
    // This would use a native module to get the actual IP
    // For now, returning a placeholder
    return '192.168.1.100';
  };

  const startExpressServer = async (port) => {
    // This would start an actual Express server
    // Using native modules for Node.js runtime
    const serverConfig = {
      port,
      routes: {
        '/api/clients': 'GET,POST,PUT,DELETE',
        '/api/scan': 'POST',
        '/api/plugin-generator': 'POST',
        '/webhook/site-data': 'POST'
      }
    };
    
    // Server would handle:
    // 1. Client management API
    // 2. WordPress site scanning
    // 3. Plugin generation
    // 4. Webhook endpoints for site data
    
    console.log('Express server started on port', port);
  };

  const configureCloudflareDNS = async (ipAddress) => {
    if (!cloudflareApiKey || !cloudflareEmail || !cloudflareZoneId) {
      Alert.alert('Error', 'Cloudflare credentials not configured');
      return;
    }

    try {
      const response = await fetch(`https://api.cloudflare.com/client/v4/zones/${cloudflareZoneId}/dns_records`, {
        method: 'POST',
        headers: {
          'X-Auth-Email': cloudflareEmail,
          'X-Auth-Key': cloudflareApiKey,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          type: 'A',
          name: 'connect.elephunkie.com',
          content: ipAddress,
          ttl: 120
        })
      });

      const result = await response.json();
      
      if (result.success) {
        Alert.alert('Success', 'Cloudflare DNS configured successfully');
      } else {
        Alert.alert('Error', `Cloudflare DNS configuration failed: ${result.errors[0]?.message}`);
      }
    } catch (error) {
      console.error('Cloudflare DNS error:', error);
      Alert.alert('Error', 'Failed to configure Cloudflare DNS');
    }
  };

  const addClient = async () => {
    if (!newClient.name || !newClient.domain) {
      Alert.alert('Error', 'Please fill in all required fields');
      return;
    }

    try {
      const clientId = Date.now().toString();
      const apiKey = generateApiKey();
      const secretKey = generateSecretKey();
      
      const client = {
        id: clientId,
        ...newClient,
        apiKey,
        secretKey,
        status: 'pending',
        createdAt: new Date().toISOString(),
        lastScan: null,
        plugins: [],
        themes: [],
        coreVersion: null,
        errors: []
      };

      const updatedClients = [...clients, client];
      setClients(updatedClients);
      await AsyncStorage.setItem('clients', JSON.stringify(updatedClients));

      // Generate WordPress plugin for this client
      await generateWordPressPlugin(client);

      setNewClient({ name: '', domain: '', adminUrl: '', adminUser: '', adminPass: '' });
      setShowAddClient(false);

      Alert.alert(
        'Success', 
        'Client added successfully! WordPress plugin has been generated.',
        [
          { text: 'OK' },
          { text: 'Download Plugin', onPress: () => downloadPlugin(clientId) }
        ]
      );
    } catch (error) {
      console.error('Error adding client:', error);
      Alert.alert('Error', 'Failed to add client');
    }
  };

  const generateApiKey = () => {
    return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
  };

  const generateSecretKey = () => {
    return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
  };

  const generateWordPressPlugin = async (client) => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/plugin-generator`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          clientId: client.id,
          clientName: client.name,
          apiKey: client.apiKey,
          secretKey: client.secretKey,
          serverUrl: API_BASE_URL
        })
      });

      if (response.ok) {
        console.log('WordPress plugin generated successfully');
      } else {
        throw new Error('Failed to generate plugin');
      }
    } catch (error) {
      console.error('Error generating WordPress plugin:', error);
    }
  };

  const downloadPlugin = async (clientId) => {
    try {
      const client = clients.find(c => c.id === clientId);
      if (!client) return;

      const pluginUrl = `${API_BASE_URL}/downloads/wp-maintenance-plugin-${clientId}.zip`;
      
      if (Platform.OS === 'ios') {
        await Linking.openURL(pluginUrl);
      } else {
        await Share.share({
          message: `Download WordPress maintenance plugin: ${pluginUrl}`,
          url: pluginUrl
        });
      }
    } catch (error) {
      console.error('Error downloading plugin:', error);
      Alert.alert('Error', 'Failed to download plugin');
    }
  };

  const scanClient = async (clientId) => {
    try {
      const client = clients.find(c => c.id === clientId);
      if (!client) return;

      const response = await fetch(`${API_BASE_URL}/api/scan`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          clientId: client.id,
          domain: client.domain,
          apiKey: client.apiKey
        })
      });

      const scanResult = await response.json();
      
      if (scanResult.success) {
        // Update client with scan results
        const updatedClients = clients.map(c => 
          c.id === clientId 
            ? { 
                ...c, 
                lastScan: new Date().toISOString(),
                plugins: scanResult.plugins,
                themes: scanResult.themes,
                coreVersion: scanResult.coreVersion,
                status: scanResult.status,
                errors: scanResult.errors
              }
            : c
        );
        
        setClients(updatedClients);
        await AsyncStorage.setItem('clients', JSON.stringify(updatedClients));
        
        Alert.alert('Success', 'Site scan completed successfully');
      } else {
        Alert.alert('Error', `Scan failed: ${scanResult.message}`);
      }
    } catch (error) {
      console.error('Error scanning client:', error);
      Alert.alert('Error', 'Failed to scan client site');
    }
  };

  const refreshData = async () => {
    setRefreshing(true);
    
    // Scan all clients
    for (const client of clients) {
      await scanClient(client.id);
    }
    
    setRefreshing(false);
  };

  const saveSettings = async () => {
    try {
      const settings = {
        cloudflareApiKey,
        cloudflareEmail,
        cloudflareZoneId,
        serverUrl
      };
      
      await AsyncStorage.setItem('settings', JSON.stringify(settings));
      setShowSettings(false);
      Alert.alert('Success', 'Settings saved successfully');
      
      // Restart server with new settings
      await startServer();
    } catch (error) {
      console.error('Error saving settings:', error);
      Alert.alert('Error', 'Failed to save settings');
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'healthy': return '#10B981';
      case 'warning': return '#F59E0B';
      case 'critical': return '#EF4444';
      case 'pending': return '#6B7280';
      default: return '#6B7280';
    }
  };

  const renderClient = ({ item }) => (
    <View style={styles.clientCard}>
      <View style={styles.clientHeader}>
        <Text style={styles.clientName}>{item.name}</Text>
        <View style={[styles.statusBadge, { backgroundColor: getStatusColor(item.status) }]}>
          <Text style={styles.statusText}>{item.status}</Text>
        </View>
      </View>
      
      <Text style={styles.clientDomain}>{item.domain}</Text>
      
      <View style={styles.clientStats}>
        <Text style={styles.statText}>Plugins: {item.plugins?.length || 0}</Text>
        <Text style={styles.statText}>Updates: {item.plugins?.filter(p => p.needsUpdate).length || 0}</Text>
        <Text style={styles.statText}>Errors: {item.errors?.length || 0}</Text>
      </View>
      
      <View style={styles.clientActions}>
        <TouchableOpacity 
          style={[styles.actionButton, styles.scanButton]}
          onPress={() => scanClient(item.id)}
        >
          <Text style={styles.actionButtonText}>Scan</Text>
        </TouchableOpacity>
        
        <TouchableOpacity 
          style={[styles.actionButton, styles.downloadButton]}
          onPress={() => downloadPlugin(item.id)}
        >
          <Text style={styles.actionButtonText}>Plugin</Text>
        </TouchableOpacity>
      </View>
      
      {item.lastScan && (
        <Text style={styles.lastScan}>
          Last scan: {new Date(item.lastScan).toLocaleDateString()}
        </Text>
      )}
    </View>
  );

  return (
    <SafeAreaProvider>
      <SafeAreaView style={styles.container}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.title}>WP Maintenance Hub</Text>
          <View style={styles.headerActions}>
            <TouchableOpacity 
              style={styles.headerButton}
              onPress={() => setShowSettings(true)}
            >
              <Text style={styles.headerButtonText}>Settings</Text>
            </TouchableOpacity>
            <TouchableOpacity 
              style={[styles.headerButton, styles.addButton]}
              onPress={() => setShowAddClient(true)}
            >
              <Text style={styles.headerButtonText}>Add Client</Text>
            </TouchableOpacity>
          </View>
        </View>

        {/* Server Status */}
        <View style={styles.serverStatus}>
          <Text style={styles.serverStatusText}>
            Server: {serverStatus} | {serverUrl}
          </Text>
        </View>

        {/* Client List */}
        <FlatList
          data={clients}
          renderItem={renderClient}
          keyExtractor={(item) => item.id}
          style={styles.clientList}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={refreshData} />
          }
          ListEmptyComponent={
            <View style={styles.emptyState}>
              <Text style={styles.emptyStateText}>No clients added yet</Text>
              <TouchableOpacity 
                style={styles.emptyStateButton}
                onPress={() => setShowAddClient(true)}
              >
                <Text style={styles.emptyStateButtonText}>Add Your First Client</Text>
              </TouchableOpacity>
            </View>
          }
        />

        {/* Add Client Modal */}
        <Modal visible={showAddClient} animationType="slide">
          <SafeAreaView style={styles.modalContainer}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Add New Client</Text>
              <TouchableOpacity onPress={() => setShowAddClient(false)}>
                <Text style={styles.closeButton}>Cancel</Text>
              </TouchableOpacity>
            </View>
            
            <ScrollView style={styles.modalContent}>
              <Text style={styles.inputLabel}>Client Name *</Text>
              <TextInput
                style={styles.input}
                value={newClient.name}
                onChangeText={(text) => setNewClient({...newClient, name: text})}
                placeholder="Enter client name"
              />
              
              <Text style={styles.inputLabel}>Domain *</Text>
              <TextInput
                style={styles.input}
                value={newClient.domain}
                onChangeText={(text) => setNewClient({...newClient, domain: text})}
                placeholder="example.com"
                autoCapitalize="none"
              />
              
              <Text style={styles.inputLabel}>Admin URL</Text>
              <TextInput
                style={styles.input}
                value={newClient.adminUrl}
                onChangeText={(text) => setNewClient({...newClient, adminUrl: text})}
                placeholder="https://example.com/wp-admin"
                autoCapitalize="none"
              />
              
              <Text style={styles.inputLabel}>Admin Username</Text>
              <TextInput
                style={styles.input}
                value={newClient.adminUser}
                onChangeText={(text) => setNewClient({...newClient, adminUser: text})}
                placeholder="WordPress admin username"
                autoCapitalize="none"
              />
              
              <Text style={styles.inputLabel}>Admin Password</Text>
              <TextInput
                style={styles.input}
                value={newClient.adminPass}
                onChangeText={(text) => setNewClient({...newClient, adminPass: text})}
                placeholder="WordPress admin password"
                secureTextEntry
              />
              
              <TouchableOpacity style={styles.saveButton} onPress={addClient}>
                <Text style={styles.saveButtonText}>Add Client & Generate Plugin</Text>
              </TouchableOpacity>
            </ScrollView>
          </SafeAreaView>
        </Modal>

        {/* Settings Modal */}
        <Modal visible={showSettings} animationType="slide">
          <SafeAreaView style={styles.modalContainer}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Settings</Text>
              <TouchableOpacity onPress={() => setShowSettings(false)}>
                <Text style={styles.closeButton}>Cancel</Text>
              </TouchableOpacity>
            </View>
            
            <ScrollView style={styles.modalContent}>
              <Text style={styles.inputLabel}>Cloudflare Email</Text>
              <TextInput
                style={styles.input}
                value={cloudflareEmail}
                onChangeText={setCloudflareEmail}
                placeholder="your-email@example.com"
                autoCapitalize="none"
              />
              
              <Text style={styles.inputLabel}>Cloudflare API Key</Text>
              <TextInput
                style={styles.input}
                value={cloudflareApiKey}
                onChangeText={setCloudflareApiKey}
                placeholder="Your Cloudflare Global API Key"
                secureTextEntry
              />
              
              <Text style={styles.inputLabel}>Cloudflare Zone ID</Text>
              <TextInput
                style={styles.input}
                value={cloudflareZoneId}
                onChangeText={setCloudflareZoneId}
                placeholder="Zone ID for elephunkie.com"
              />
              
              <TouchableOpacity style={styles.saveButton} onPress={saveSettings}>
                <Text style={styles.saveButtonText}>Save Settings</Text>
              </TouchableOpacity>
            </ScrollView>
          </SafeAreaView>
        </Modal>
      </SafeAreaView>
    </SafeAreaProvider>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F9FAFB'
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E5E7EB'
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#111827'
  },
  headerActions: {
    flexDirection: 'row',
    gap: 8
  },
  headerButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 6,
    backgroundColor: '#E5E7EB'
  },
  addButton: {
    backgroundColor: '#3B82F6'
  },
  headerButtonText: {
    color: '#FFFFFF',
    fontWeight: '600'
  },
  serverStatus: {
    padding: 12,
    backgroundColor: '#F3F4F6',
    borderBottomWidth: 1,
    borderBottomColor: '#E5E7EB'
  },
  serverStatusText: {
    fontSize: 12,
    color: '#6B7280',
    textAlign: 'center'
  },
  clientList: {
    flex: 1,
    padding: 16
  },
  clientCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 8,
    padding: 16,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2
  },
  clientHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8
  },
  clientName: {
    fontSize: 18,
    fontWeight: '600',
    color: '#111827'
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12
  },
  statusText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600'
  },
  clientDomain: {
    fontSize: 14,
    color: '#6B7280',
    marginBottom: 12
  },
  clientStats: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 12
  },
  statText: {
    fontSize: 12,
    color: '#374151'
  },
  clientActions: {
    flexDirection: 'row',
    gap: 8,
    marginBottom: 8
  },
  actionButton: {
    flex: 1,
    paddingVertical: 8,
    borderRadius: 6,
    alignItems: 'center'
  },
  scanButton: {
    backgroundColor: '#10B981'
  },
  downloadButton: {
    backgroundColor: '#3B82F6'
  },
  actionButtonText: {
    color: '#FFFFFF',
    fontWeight: '600',
    fontSize: 14
  },
  lastScan: {
    fontSize: 10,
    color: '#9CA3AF',
    textAlign: 'center'
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingTop: 100
  },
  emptyStateText: {
    fontSize: 16,
    color: '#6B7280',
    marginBottom: 20
  },
  emptyStateButton: {
    backgroundColor: '#3B82F6',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 8
  },
  emptyStateButtonText: {
    color: '#FFFFFF',
    fontWeight: '600'
  },
  modalContainer: {
    flex: 1,
    backgroundColor: '#FFFFFF'
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#E5E7EB'
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#111827'
  },
  closeButton: {
    color: '#3B82F6',
    fontSize: 16
  },
  modalContent: {
    flex: 1,
    padding: 16
  },
  inputLabel: {
    fontSize: 14,
    fontWeight: '500',
    color: '#374151',
    marginBottom: 6,
    marginTop: 16
  },
  input: {
    borderWidth: 1,
    borderColor: '#D1D5DB',
    borderRadius: 6,
    padding: 12,
    fontSize: 16,
    backgroundColor: '#FFFFFF'
  },
  saveButton: {
    backgroundColor: '#3B82F6',
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 24
  },
  saveButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600'
  }
});

export default WPMaintenanceApp;