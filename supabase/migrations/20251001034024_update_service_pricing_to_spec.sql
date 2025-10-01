/*
  # Update Service Pricing to Specified Rates

  ## Summary
  This migration updates all service pricing in the database to match the specified rates.
  All prices are stored in USD as the base currency.

  ## Services Being Updated

  1. **Email Migration & Setup**
     - Changed from variable pricing to $4.00 per mailbox
     - Pricing structure: Single tier (per mailbox)

  2. **Acronis Account Setup**
     - Updated to $25.00 (one-time setup)
     - Pricing structure: Single tier (complete setup)

  3. **Cloud Suite Management**
     - Updated to $25.00 (one-time setup)
     - Pricing structure: Single tier with optional $5.00 per incident

  4. **Email Deliverability (Domain & Email Security)**
     - Updated to $25.00 (complete setup)
     - Pricing structure: Single tier (complete DNS and email auth setup)

  5. **Per Incident Support**
     - Updated to $20.00 per incident
     - Pricing structure: Single tier (per incident)

  6. **SSL Setup**
     - Basic (Free SSL): $7.00
     - Standard (Single Domain): $10.00
     - Enterprise (Multi-Domain): $25.00

  7. **Data Migration (Cloud Data Migration)**
     - Updated to $5.00 per user
     - Pricing structure: Single tier (per user)

  8. **Hosting Support**
     - Basic: $15.00
     - Standard: $25.00
     - Enterprise: $55.00

  ## Important Notes
  - All prices are in USD (base currency)
  - Currency conversion happens at the application layer
  - This migration uses safe UPDATE operations
  - Foreign key relationships are preserved
  - No system triggers are modified
*/

-- Update Email Migration & Setup pricing
UPDATE services
SET 
  pricing = jsonb_build_object(
    'basic', 4
  ),
  description = 'Seamless email migration between platforms with zero downtime - $4.00 per mailbox',
  features = jsonb_build_object(
    'basic', jsonb_build_array(
      'Complete mailbox migration',
      'Email backup included',
      'Zero downtime migration',
      'Basic support'
    )
  )
WHERE name = 'Email Migration & Setup';

-- Update Cloud Suite Management pricing
UPDATE services
SET 
  pricing = jsonb_build_object(
    'basic', 25,
    'standard', 5
  ),
  description = 'Expert administration of Google Workspace and Microsoft 365 environments - $25.00 one-time setup',
  features = jsonb_build_object(
    'basic', jsonb_build_array(
      'Initial setup & configuration',
      'User account creation',
      'Basic troubleshooting',
      'Documentation provided'
    ),
    'standard', jsonb_build_array(
      'Per-incident support',
      'Additional troubleshooting',
      'Configuration changes',
      'Quick resolution'
    )
  )
WHERE name = 'Cloud Suite Management';

-- Update Domain & Email Security (Email Deliverability) pricing
UPDATE services
SET 
  pricing = jsonb_build_object(
    'basic', 25
  ),
  description = 'Complete DNS and email authentication setup including SPF, DKIM, and DMARC - $25.00',
  features = jsonb_build_object(
    'basic', jsonb_build_array(
      'SPF, DKIM, DMARC setup',
      'DNS configuration',
      'Deliverability optimization',
      'Email support'
    )
  )
WHERE name = 'Domain & Email Security';

-- Update SSL & HTTPS Setup pricing
UPDATE services
SET 
  pricing = jsonb_build_object(
    'basic', 7,
    'standard', 10,
    'enterprise', 25
  ),
  description = 'Professional SSL certificate installation and automated renewal systems',
  features = jsonb_build_object(
    'basic', jsonb_build_array(
      'Free SSL certificate (Let''s Encrypt)',
      'Installation & configuration',
      'Auto-renewal setup',
      'Basic support'
    ),
    'standard', jsonb_build_array(
      'Paid SSL (Single Domain)',
      'Client-provided certificate',
      'Professional installation',
      'Priority support'
    ),
    'enterprise', jsonb_build_array(
      'Paid SSL (Multi-Domain)',
      'Up to 5 domains',
      'Complete configuration',
      'Advanced support'
    )
  )
WHERE name = 'SSL & HTTPS Setup';

-- Update Cloud Data Migration pricing
UPDATE services
SET 
  pricing = jsonb_build_object(
    'basic', 5
  ),
  description = 'Secure migration between Microsoft Teams, SharePoint, OneDrive, and Google Drive - $5.00 per user',
  features = jsonb_build_object(
    'basic', jsonb_build_array(
      'Microsoft Teams chat migration',
      'SharePoint site migration',
      'OneDrive migration',
      'Google Drive migration'
    )
  )
WHERE name = 'Cloud Data Migration';

-- Update Hosting & Control Panel Support pricing
UPDATE services
SET 
  pricing = jsonb_build_object(
    'basic', 15,
    'standard', 25,
    'enterprise', 55
  ),
  description = 'Professional troubleshooting and optimization for Plesk and cPanel',
  features = jsonb_build_object(
    'basic', jsonb_build_array(
      'Basic troubleshooting',
      'Performance optimization',
      'Email support',
      'Monthly check-up'
    ),
    'standard', jsonb_build_array(
      'Everything in Basic',
      'Priority support',
      'Security hardening',
      'Weekly monitoring',
      'Backup management'
    ),
    'enterprise', jsonb_build_array(
      'Everything in Standard',
      '24/7 monitoring',
      'Dedicated support',
      'Custom configurations',
      'Emergency response'
    )
  )
WHERE name = 'Hosting & Control Panel Support';

-- Add Per Incident Support service if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM services WHERE name LIKE '%Per Incident%' OR name LIKE '%Incident Support%'
  ) THEN
    INSERT INTO services (name, description, category, pricing, features)
    VALUES (
      'Per Incident Support',
      'Quick resolution for specific IT issues across all platforms - $20.00 per incident',
      'support',
      jsonb_build_object('basic', 20),
      jsonb_build_object(
        'basic', jsonb_build_array(
          'Expert troubleshooting',
          'Quick issue resolution',
          '7-day follow-up support',
          'Documentation provided'
        )
      )
    );
  ELSE
    -- Update existing Per Incident Support
    UPDATE services
    SET 
      pricing = jsonb_build_object('basic', 20),
      description = 'Quick resolution for specific IT issues across all platforms - $20.00 per incident',
      features = jsonb_build_object(
        'basic', jsonb_build_array(
          'Expert troubleshooting',
          'Quick issue resolution',
          '7-day follow-up support',
          'Documentation provided'
        )
      )
    WHERE name LIKE '%Per Incident%' OR name LIKE '%Incident Support%';
  END IF;
END $$;

-- Add Acronis Account Setup if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM services WHERE name LIKE '%Acronis%'
  ) THEN
    INSERT INTO services (name, description, category, pricing, features)
    VALUES (
      'Acronis Account Setup',
      'One-time Acronis backup solution setup and configuration - $25.00',
      'backup',
      jsonb_build_object('basic', 25),
      jsonb_build_object(
        'basic', jsonb_build_array(
          'Acronis account creation',
          'Complete configuration',
          'Multi-device setup',
          'Training and support'
        )
      )
    );
  ELSE
    -- Update existing Acronis service
    UPDATE services
    SET 
      pricing = jsonb_build_object('basic', 25),
      description = 'One-time Acronis backup solution setup and configuration - $25.00',
      features = jsonb_build_object(
        'basic', jsonb_build_array(
          'Acronis account creation',
          'Complete configuration',
          'Multi-device setup',
          'Training and support'
        )
      )
    WHERE name LIKE '%Acronis%';
  END IF;
END $$;

-- Verify pricing updates
DO $$
DECLARE
  service_record RECORD;
  pricing_summary TEXT := E'\n=== PRICING UPDATE SUMMARY ===\n';
BEGIN
  FOR service_record IN
    SELECT name, pricing FROM services ORDER BY name
  LOOP
    pricing_summary := pricing_summary || service_record.name || ': ' || service_record.pricing::text || E'\n';
  END LOOP;
  
  RAISE NOTICE '%', pricing_summary;
END $$;