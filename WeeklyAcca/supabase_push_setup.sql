-- 1. Add APNs Token column to profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS apns_token TEXT;

-- 2. Create the Trigger Function to call the Edge Function
-- Replace 'YOUR_SUPABASE_PROJECT_URL' and 'YOUR_ANON_KEY' with your actual values from the API settings.
CREATE OR REPLACE FUNCTION public.notify_new_acca()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- We use the pg_net extension to make an HTTP POST request to the Edge Function
  -- Ensure pg_net is enabled in Database -> Extensions
  
  PERFORM net.http_post(
      url:='https://YOUR_SUPABASE_PROJECT_URL.supabase.co/functions/v1/send-acca-notification',
      headers:='{"Content-Type": "application/json", "Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb,
      body:=json_build_object('record', row_to_json(NEW))::jsonb
  );
  
  RETURN NEW;
END;
$$;

-- 3. Attach the Trigger to the accas table
DROP TRIGGER IF EXISTS on_new_acca_created ON public.accas;
CREATE TRIGGER on_new_acca_created
AFTER INSERT ON public.accas
FOR EACH ROW
EXECUTE FUNCTION public.notify_new_acca();
