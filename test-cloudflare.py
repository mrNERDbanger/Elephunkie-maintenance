#!/usr/bin/env python3
import requests
import json

# Test Cloudflare credentials
API_TOKEN = "XspvHdYi9Y3YSI96_5sF3pYYb4O0nW1-69Z9K2vB"
ZONE_ID = "f3830ecd755d9a9fce0706a76853bef3"

def test_credentials():
    print("Testing Cloudflare API credentials...")
    
    headers = {
        "Authorization": f"Bearer {API_TOKEN}",
        "Content-Type": "application/json"
    }
    
    # Test 1: List DNS records
    url = f"https://api.cloudflare.com/client/v4/zones/{ZONE_ID}/dns_records"
    
    try:
        response = requests.get(url, headers=headers, timeout=10)
        print(f"Response status: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ Credentials are valid!")
            
            data = response.json()
            if 'result' in data:
                print(f"\nFound {len(data['result'])} DNS records:")
                for record in data['result'][:5]:  # Show first 5
                    print(f"  - {record['type']}: {record['name']} -> {record['content']}")
        else:
            print("❌ Invalid credentials or permissions")
            print(f"Error: {response.text}")
            
    except Exception as e:
        print(f"❌ Network error: {e}")

def test_zone_info():
    print("\nGetting zone information...")
    
    headers = {
        "Authorization": f"Bearer {API_TOKEN}",
        "Content-Type": "application/json"
    }
    
    url = f"https://api.cloudflare.com/client/v4/zones/{ZONE_ID}"
    
    try:
        response = requests.get(url, headers=headers, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            zone_name = data['result']['name']
            print(f"✅ Zone name: {zone_name}")
            print(f"✅ Zone ID verified: {ZONE_ID}")
        else:
            print(f"❌ Failed to get zone info: {response.text}")
            
    except Exception as e:
        print(f"❌ Error getting zone info: {e}")

if __name__ == "__main__":
    test_credentials()
    test_zone_info()