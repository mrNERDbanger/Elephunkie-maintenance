import Foundation

class PluginGenerator {
    static func generatePlugin(for client: Client, hubEndpoint: String) -> String {
        let pluginName = "elephunkie-\(client.name.lowercased().replacingOccurrences(of: " ", with: "-"))"
        
        return """
        <?php
        /**
         * Plugin Name: Elephunkie Maintenance - \(client.name)
         * Description: Client-specific maintenance plugin for \(client.name)
         * Version: 1.0.0
         * Author: Elephunkie
         * License: Proprietary
         */
        
        // Prevent direct access
        if (!defined('ABSPATH')) {
            exit;
        }
        
        // Define constants
        define('ELEPHUNKIE_CLIENT_ID', '\(client.id.uuidString)');
        define('ELEPHUNKIE_AUTH_TOKEN', '\(client.authToken)');
        define('ELEPHUNKIE_HUB_ENDPOINT', '\(hubEndpoint)');
        define('ELEPHUNKIE_CLIENT_NAME', '\(client.name)');
        
        class ElephunkieMaintenanceClient {
            private static $instance = null;
            
            public static function getInstance() {
                if (self::$instance == null) {
                    self::$instance = new ElephunkieMaintenanceClient();
                }
                return self::$instance;
            }
            
            private function __construct() {
                // Register hooks
                add_action('init', array($this, 'init'));
                add_action('rest_api_init', array($this, 'register_api_routes'));
                add_action('elephunkie_daily_health_check', array($this, 'send_health_check'));
                
                // Admin hooks
                if (is_admin()) {
                    add_action('admin_menu', array($this, 'add_admin_menu'));
                    add_action('admin_enqueue_scripts', array($this, 'enqueue_admin_scripts'));
                }
                
                // Monitor events
                add_action('activated_plugin', array($this, 'log_plugin_activation'), 10, 2);
                add_action('deactivated_plugin', array($this, 'log_plugin_deactivation'), 10, 2);
                add_action('upgrader_process_complete', array($this, 'log_updates'), 10, 2);
                add_action('wp_login_failed', array($this, 'log_failed_login'));
                add_action('wp_login', array($this, 'log_successful_login'), 10, 2);
                
                // Schedule cron
                if (!wp_next_scheduled('elephunkie_daily_health_check')) {
                    wp_schedule_event(time(), 'daily', 'elephunkie_daily_health_check');
                }
            }
            
            public function init() {
                // Register with hub on activation
                if (get_option('elephunkie_registered') !== 'yes') {
                    $this->register_with_hub();
                }
            }
            
            public function register_api_routes() {
                register_rest_route('elephunkie/v1', '/status', array(
                    'methods' => 'GET',
                    'callback' => array($this, 'get_status'),
                    'permission_callback' => array($this, 'verify_auth_token')
                ));
                
                register_rest_route('elephunkie/v1', '/scan', array(
                    'methods' => 'POST',
                    'callback' => array($this, 'perform_scan'),
                    'permission_callback' => array($this, 'verify_auth_token')
                ));
                
                register_rest_route('elephunkie/v1', '/update', array(
                    'methods' => 'POST',
                    'callback' => array($this, 'perform_update'),
                    'permission_callback' => array($this, 'verify_auth_token')
                ));
            }
            
            public function verify_auth_token($request) {
                $token = $request->get_header('X-Auth-Token');
                return $token === ELEPHUNKIE_AUTH_TOKEN;
            }
            
            public function get_status() {
                return new WP_REST_Response(array(
                    'status' => 'healthy',
                    'client_id' => ELEPHUNKIE_CLIENT_ID,
                    'wordpress_version' => get_bloginfo('version'),
                    'php_version' => phpversion(),
                    'timestamp' => current_time('c')
                ), 200);
            }
            
            public function perform_scan() {
                $scan_data = array(
                    'client_id' => ELEPHUNKIE_CLIENT_ID,
                    'site_url' => get_site_url(),
                    'wordpress_version' => get_bloginfo('version'),
                    'php_version' => phpversion(),
                    'active_theme' => wp_get_theme()->get('Name'),
                    'plugins' => $this->get_plugins_data(),
                    'themes' => $this->get_themes_data(),
                    'users_count' => count_users()['total_users'],
                    'health_metrics' => $this->get_health_metrics(),
                    'timestamp' => current_time('c')
                );
                
                // Send to hub
                $this->send_to_hub('/api/scan-results', $scan_data);
                
                return new WP_REST_Response(array('success' => true, 'data' => $scan_data), 200);
            }
            
            public function perform_update($request) {
                $update_type = $request->get_param('type');
                $items = $request->get_param('items');
                
                if (!current_user_can('update_plugins') && !current_user_can('update_themes')) {
                    return new WP_Error('permission_denied', 'Insufficient permissions', array('status' => 403));
                }
                
                $results = array();
                
                switch ($update_type) {
                    case 'plugins':
                        foreach ($items as $plugin) {
                            $result = $this->update_plugin($plugin);
                            $results[] = $result;
                        }
                        break;
                    case 'themes':
                        foreach ($items as $theme) {
                            $result = $this->update_theme($theme);
                            $results[] = $result;
                        }
                        break;
                    case 'core':
                        $result = $this->update_core();
                        $results[] = $result;
                        break;
                }
                
                return new WP_REST_Response(array('success' => true, 'results' => $results), 200);
            }
            
            private function get_plugins_data() {
                if (!function_exists('get_plugins')) {
                    require_once ABSPATH . 'wp-admin/includes/plugin.php';
                }
                
                $all_plugins = get_plugins();
                $active_plugins = get_option('active_plugins', array());
                $updates = get_site_transient('update_plugins');
                
                $plugins_data = array();
                
                foreach ($all_plugins as $plugin_file => $plugin_data) {
                    $update_available = isset($updates->response[$plugin_file]) ? 
                        $updates->response[$plugin_file]->new_version : null;
                    
                    $plugins_data[] = array(
                        'name' => $plugin_data['Name'],
                        'slug' => dirname($plugin_file),
                        'version' => $plugin_data['Version'],
                        'is_active' => in_array($plugin_file, $active_plugins),
                        'update_available' => $update_available
                    );
                }
                
                return $plugins_data;
            }
            
            private function get_themes_data() {
                $themes = wp_get_themes();
                $current_theme = wp_get_theme();
                $updates = get_site_transient('update_themes');
                
                $themes_data = array();
                
                foreach ($themes as $theme_slug => $theme) {
                    $update_available = isset($updates->response[$theme_slug]) ? 
                        $updates->response[$theme_slug]['new_version'] : null;
                    
                    $themes_data[] = array(
                        'name' => $theme->get('Name'),
                        'slug' => $theme_slug,
                        'version' => $theme->get('Version'),
                        'is_active' => ($theme_slug === $current_theme->get_stylesheet()),
                        'update_available' => $update_available
                    );
                }
                
                return $themes_data;
            }
            
            private function get_health_metrics() {
                global $wpdb;
                
                // Get database size
                $db_size = $wpdb->get_var("
                    SELECT SUM(data_length + index_length) 
                    FROM information_schema.TABLES 
                    WHERE table_schema = '" . DB_NAME . "'
                ");
                
                return array(
                    'database_size' => $db_size,
                    'upload_dir_size' => $this->get_directory_size(wp_upload_dir()['basedir']),
                    'error_count' => $this->get_recent_errors_count(),
                    'last_backup' => get_option('elephunkie_last_backup', null),
                    'security_issues' => $this->check_security_issues()
                );
            }
            
            private function get_directory_size($dir) {
                $size = 0;
                foreach (glob(rtrim($dir, '/').'/*', GLOB_NOSORT) as $each) {
                    $size += is_file($each) ? filesize($each) : $this->get_directory_size($each);
                }
                return $size;
            }
            
            private function get_recent_errors_count() {
                // Implementation depends on error logging setup
                return 0;
            }
            
            private function check_security_issues() {
                $issues = 0;
                
                // Check for debug mode
                if (defined('WP_DEBUG') && WP_DEBUG) {
                    $issues++;
                }
                
                // Check file permissions
                if (is_writable(ABSPATH . 'wp-config.php')) {
                    $issues++;
                }
                
                // Check for default admin username
                if (username_exists('admin')) {
                    $issues++;
                }
                
                return $issues;
            }
            
            private function send_to_hub($endpoint, $data) {
                $response = wp_remote_post(ELEPHUNKIE_HUB_ENDPOINT . $endpoint, array(
                    'method' => 'POST',
                    'timeout' => 30,
                    'headers' => array(
                        'Content-Type' => 'application/json',
                        'X-Client-ID' => ELEPHUNKIE_CLIENT_ID,
                        'X-Auth-Token' => ELEPHUNKIE_AUTH_TOKEN
                    ),
                    'body' => json_encode($data),
                    'sslverify' => true
                ));
                
                if (is_wp_error($response)) {
                    error_log('Elephunkie: Failed to send data to hub - ' . $response->get_error_message());
                    return false;
                }
                
                return true;
            }
            
            private function register_with_hub() {
                $registration_data = array(
                    'client_id' => ELEPHUNKIE_CLIENT_ID,
                    'client_name' => ELEPHUNKIE_CLIENT_NAME,
                    'site_url' => get_site_url(),
                    'admin_email' => get_option('admin_email'),
                    'wordpress_version' => get_bloginfo('version'),
                    'php_version' => phpversion()
                );
                
                if ($this->send_to_hub('/api/register', $registration_data)) {
                    update_option('elephunkie_registered', 'yes');
                }
            }
            
            public function send_health_check() {
                $this->perform_scan();
            }
            
            public function add_admin_menu() {
                add_menu_page(
                    'Elephunkie Maintenance',
                    'Elephunkie',
                    'manage_options',
                    'elephunkie-maintenance',
                    array($this, 'admin_page'),
                    'dashicons-shield-alt',
                    100
                );
            }
            
            public function admin_page() {
                ?>
                <div class="wrap">
                    <h1>Elephunkie Maintenance - <?php echo esc_html(ELEPHUNKIE_CLIENT_NAME); ?></h1>
                    <div class="elephunkie-status-card">
                        <h2>Connection Status</h2>
                        <p>Client ID: <code><?php echo esc_html(ELEPHUNKIE_CLIENT_ID); ?></code></p>
                        <p>Hub Endpoint: <code><?php echo esc_html(ELEPHUNKIE_HUB_ENDPOINT); ?></code></p>
                        <p>Last Check: <?php echo esc_html(get_option('elephunkie_last_check', 'Never')); ?></p>
                        <button class="button button-primary" id="elephunkie-test-connection">Test Connection</button>
                    </div>
                </div>
                <?php
            }
            
            public function enqueue_admin_scripts($hook) {
                if ($hook !== 'toplevel_page_elephunkie-maintenance') {
                    return;
                }
                
                wp_enqueue_script('elephunkie-admin', plugin_dir_url(__FILE__) . 'admin.js', array('jquery'), '1.0.0', true);
                wp_localize_script('elephunkie-admin', 'elephunkie_ajax', array(
                    'ajax_url' => admin_url('admin-ajax.php'),
                    'nonce' => wp_create_nonce('elephunkie_nonce')
                ));
            }
            
            // Event logging methods
            public function log_plugin_activation($plugin, $network_wide) {
                $this->log_event('plugin_activated', array('plugin' => $plugin));
            }
            
            public function log_plugin_deactivation($plugin, $network_wide) {
                $this->log_event('plugin_deactivated', array('plugin' => $plugin));
            }
            
            public function log_updates($upgrader_object, $options) {
                if ($options['type'] == 'plugin' && $options['action'] == 'update') {
                    $this->log_event('plugins_updated', array('plugins' => $options['plugins']));
                }
            }
            
            public function log_failed_login($username) {
                $this->log_event('login_failed', array('username' => $username, 'ip' => $_SERVER['REMOTE_ADDR']));
            }
            
            public function log_successful_login($user_login, $user) {
                $this->log_event('login_success', array('username' => $user_login, 'ip' => $_SERVER['REMOTE_ADDR']));
            }
            
            private function log_event($event_type, $data) {
                $event_data = array(
                    'client_id' => ELEPHUNKIE_CLIENT_ID,
                    'event_type' => $event_type,
                    'data' => $data,
                    'timestamp' => current_time('c')
                );
                
                $this->send_to_hub('/api/events', $event_data);
            }
            
            // Update methods
            private function update_plugin($plugin_slug) {
                if (!function_exists('get_plugin_updates')) {
                    require_once ABSPATH . 'wp-admin/includes/update.php';
                    require_once ABSPATH . 'wp-admin/includes/plugin.php';
                }
                
                $updates = get_plugin_updates();
                
                foreach ($updates as $plugin_file => $plugin_data) {
                    if (dirname($plugin_file) === $plugin_slug) {
                        $result = wp_update_plugin($plugin_file);
                        return array(
                            'plugin' => $plugin_slug,
                            'success' => !is_wp_error($result),
                            'message' => is_wp_error($result) ? $result->get_error_message() : 'Updated successfully'
                        );
                    }
                }
                
                return array('plugin' => $plugin_slug, 'success' => false, 'message' => 'Plugin not found');
            }
            
            private function update_theme($theme_slug) {
                if (!function_exists('get_theme_updates')) {
                    require_once ABSPATH . 'wp-admin/includes/update.php';
                }
                
                $updates = get_theme_updates();
                
                if (isset($updates[$theme_slug])) {
                    $result = wp_update_theme($theme_slug);
                    return array(
                        'theme' => $theme_slug,
                        'success' => !is_wp_error($result),
                        'message' => is_wp_error($result) ? $result->get_error_message() : 'Updated successfully'
                    );
                }
                
                return array('theme' => $theme_slug, 'success' => false, 'message' => 'Theme not found');
            }
            
            private function update_core() {
                if (!function_exists('get_core_updates')) {
                    require_once ABSPATH . 'wp-admin/includes/update.php';
                    require_once ABSPATH . 'wp-admin/includes/class-wp-upgrader.php';
                }
                
                $updates = get_core_updates();
                
                if (!empty($updates) && $updates[0]->response == 'upgrade') {
                    $upgrader = new Core_Upgrader();
                    $result = $upgrader->upgrade($updates[0]);
                    
                    return array(
                        'type' => 'core',
                        'success' => !is_wp_error($result),
                        'message' => is_wp_error($result) ? $result->get_error_message() : 'Updated successfully'
                    );
                }
                
                return array('type' => 'core', 'success' => false, 'message' => 'No update available');
            }
        }
        
        // Initialize the plugin
        ElephunkieMaintenanceClient::getInstance();
        
        // Deactivation hook
        register_deactivation_hook(__FILE__, function() {
            wp_clear_scheduled_hook('elephunkie_daily_health_check');
        });
        """
    }
    
    static func generateInstallInstructions(for client: Client, pluginContent: String) -> String {
        return """
        # Elephunkie Maintenance Plugin Installation Instructions
        
        ## Client: \(client.name)
        ## Site: \(client.siteURL)
        
        ### Installation Steps:
        
        1. **Save the Plugin File**
           - Save the generated plugin code as `elephunkie-maintenance.php`
           - Create a folder named `elephunkie-maintenance` in your WordPress plugins directory
           - Place the file inside this folder
        
        2. **Upload to WordPress**
           - Navigate to `/wp-content/plugins/` on your WordPress installation
           - Upload the `elephunkie-maintenance` folder
        
        3. **Activate the Plugin**
           - Log in to your WordPress admin panel
           - Go to Plugins > Installed Plugins
           - Find "Elephunkie Maintenance - \(client.name)"
           - Click "Activate"
        
        4. **Verify Connection**
           - After activation, go to the Elephunkie menu in your WordPress admin
           - Click "Test Connection" to verify the plugin can communicate with the hub
        
        ### Important Information:
        
        - **Client ID**: `\(client.id.uuidString)`
        - **Auth Token**: `\(client.authToken)`
        - **Hub Endpoint**: Will be configured automatically
        
        ### Security Notes:
        
        - This plugin is specific to your site and contains unique authentication credentials
        - Do not share this plugin with other sites
        - Keep the auth token secure and do not expose it publicly
        
        ### Support:
        
        If you encounter any issues during installation or operation, please contact Elephunkie support with your Client ID.
        """
    }
}