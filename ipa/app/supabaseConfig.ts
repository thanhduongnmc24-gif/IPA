import 'react-native-url-polyfill/auto';
import { createClient } from '@supabase/supabase-js';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';

const SUPABASE_URL = 'https://mrgsyxgucwochzhbzbrt.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1yZ3N5eGd1Y3dvY2h6aGJ6YnJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyMjk3MTUsImV4cCI6MjA3OTgwNTcxNX0.nPuAqdbjXoZ-upuU_LQrv6IVNR_2NMeioquRap-BYcE';

// Tèo đã sửa lại kiểu trả về cho đúng chuẩn TypeScript
const ExpoSecureStoreAdapter = {
  getItem: (key: string) => {
    if (Platform.OS === 'web' && typeof window === 'undefined') {
        return Promise.resolve(null); // getItem trả về null là đúng
    }
    return AsyncStorage.getItem(key);
  },
  setItem: (key: string, value: string) => {
    if (Platform.OS === 'web' && typeof window === 'undefined') {
        return Promise.resolve(); // [SỬA LỖI] Trả về void (không có null)
    }
    return AsyncStorage.setItem(key, value);
  },
  removeItem: (key: string) => {
    if (Platform.OS === 'web' && typeof window === 'undefined') {
        return Promise.resolve(); // [SỬA LỖI] Trả về void (không có null)
    }
    return AsyncStorage.removeItem(key);
  },
};

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    storage: ExpoSecureStoreAdapter,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});