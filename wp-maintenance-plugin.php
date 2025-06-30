<?php
/**
 * Plugin Name: WP Maintenance Hub Client
 * Plugin URI: https://elephunkie.com
 * Description: Connects your WordPress site to the WP Maintenance Hub for automated maintenance and monitoring.
 * Version: 1.0.0
 * Author: Your Maintenance Company
 * License: GPL v2 or later
 * Text Domain: wp-maintenance-hub
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

class WPMaintenanceHubClient {
    
    private $api_key;
    private $secret_key;
    private $server_url;
    private $client_id;
    
    public function __construct() {
        $this->api_key = get_option('wpmh_api_key', '{{API_KEY}}');
        $this->secret_key = get_option('wpmh_secret_key', '{{SECRET_KEY}}');
        $this->server_url = get_option('wpmh_server_url', '{{SERVER_URL}}');
        $this->client_id = get_option('wpmh_client_id', '{{CLIENT_ID}}');
        
        add_action('init', array($this, 'init'));
        add_action('wp_ajax_nopriv_wpmh_webhook', array($this, 'handle_webhook'));
        add_action('wp_ajax_wpmh_webhook', array($this, 'handle_webhook'));
        add_action('admin_menu', array($this, 'add_admin_menu'));
        add_action('wp_loaded', array($this, 'schedule_health_check'));
        
        // Hook into WordPress events for real-time monitoring
        add_action('upgrader_process_complete', array($this, 'on_update_complete'), 10, 2);
        add_action('wp_insert_post', array($this, 'on_content_change'));
        add_action('activated_plugin', array($this, 'on_plugin_activated'));
        add_action('deactivated_plugin', array($this, 'on_plugin_deactivated'));
        
        // Security monitoring
        add_action('wp_login_failed', array($this, 'on_login_failed'));
        add_action('wp_login', array($this, 'on_successful_login'));
        
        // Error monitoring
        register_shutdown_function(array($this, 'catch_fatal_errors'));
    }
    
    public function init() {
        // Initialize plugin settings if not exists
        if (!get_option('wpmh_api_key')) {
            $this->initialize_settings();
        }
        
        // Schedule daily health check
        if (!wp_next_scheduled('wpmh_daily_health_check')) {
            wp_schedule_event(time(), 'daily', 'wpmh_daily_health_check');
        }
        
        add_action('wpmh_daily_health_check', array($this, 'perform_health_check'));
    }
    
    private function initialize_settings() {
        update_option('wpmh_api_key', '{{API_KEY}}');
        update_option('wpmh_secret_key', '{{SECRET_KEY}}');
        update_option('wpmh_server_url', '{{SERVER_URL}}');
        update_option('wpmh_client_id', '{{CLIENT_ID}}');
        update_option('wpmh_client_name', '{{CLIENT_NAME}}');
        update_option('wpmh_installed_date', current_time('mysql'));
    }
    
    public function add_admin_menu() {
        add_options_page(
            'WP Maintenance Hub',
            'Maintenance Hub',
            'manage_options',
            'wp-maintenance-hub',
            array($this, 'admin_page')
        );
    }
    
    public function admin_page() {
        ?>
        <div class="wrap">
            <h1>WP Maintenance Hub</h1>
            
            <div class="card">
                <h2>Connection Status</h2>
                <p><strong>Status:</strong> <span id="connection-status">Checking...</span></p>
                <p><strong>Client ID:</strong> <?php echo esc_html($this->client_id); ?></p>
                <p><strong>Server URL:</strong> <?php echo esc_html($this->server_url); ?></p>
                <p><strong>Last Health Check:</strong> <?php echo get_option('wpmh_last_health_check', 'Never'); ?></p>
                
                <button type="button" id="test-connection" class="button button-primary">Test Connection</button>
                <button type="button" id="force-health-check" class="button">Force Health Check</button>
            </div>
            
            <div class="card">
                <h2>Site Information</h2>
                <table class="form-table">
                    <tr>
                        <th>WordPress Version</th>
                        <td><?php echo get_bloginfo('version'); ?></td>
                    </tr>
                    <tr>
                        <th>PHP Version</th>
                        <td><?php echo PHP_VERSION; ?></td>
                    </tr>
                    <tr>
                        <th>Active Plugins</th>
                        <td><?php echo count(get_option('active_plugins')); ?></td>
                    </tr>
                    <tr>
                        <th>Active Theme</th>
                        <td><?php echo wp_get_theme()->get('Name') . ' v' . wp_get_theme()->get('Version'); ?></td>
                    </tr>
                </table>
            </div>
            
            <div class="card">
                <h2>Recent Activity</h2>
                <div id="recent-activity">
                    <?php $this->display_recent_activity(); ?>
                </div>
            </div>
        </div>
        
        <script>
        jQuery(document).ready(function($) {
            function checkConnection() {
                $('#connection-status').text('Checking...');
                
                $.post(ajaxurl, {
                    action: 'wpmh_test_connection',
                    nonce: '<?php echo wp_create_nonce('wpmh_test_connection'); ?>'
                }, function(response)