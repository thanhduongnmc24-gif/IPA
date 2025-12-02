import React from 'react';
import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Platform } from 'react-native';

// Import ThemeProvider
import { ThemeProvider, useTheme } from './context/ThemeContext'; 

function TabLayoutInner() {
  const { colors } = useTheme();

  return (
    <Tabs screenOptions={{ 
        headerShown: false,
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.tabInactive,
        tabBarStyle: {
          backgroundColor: colors.card,
          borderTopColor: colors.border,
          borderTopWidth: 1,
          elevation: 0,
          height: Platform.OS === 'ios' ? 85 : 65,
          paddingBottom: Platform.OS === 'ios' ? 25 : 10,
          paddingTop: 10,
        },
        tabBarLabelStyle: { fontWeight: '600', fontSize: 10 }
      }}>
      
      {/* --- CÁC TAB CHÍNH (HIỂN THỊ) --- */}
      <Tabs.Screen name="index" options={{ title: 'Lịch', tabBarIcon: ({ color }) => <Ionicons name="calendar" size={24} color={color} /> }} />
      <Tabs.Screen name="notes" options={{ title: 'Ghi chú', tabBarIcon: ({ color }) => <Ionicons name="document-text" size={24} color={color} /> }} />
      <Tabs.Screen name="media" options={{ title: 'Media', tabBarIcon: ({ color }) => <Ionicons name="images" size={24} color={color} /> }} />
      <Tabs.Screen name="reminders" options={{ title: 'Nhắc nhở', tabBarIcon: ({ color }) => <Ionicons name="alarm" size={24} color={color} /> }} />
      <Tabs.Screen name="settings" options={{ title: 'Cài đặt', tabBarIcon: ({ color }) => <Ionicons name="settings" size={24} color={color} /> }} />

      {/* --- CÁC FILE CẦN ẨN KHỎI MENU (QUAN TRỌNG) --- */}
      {/* href: null nghĩa là: Đừng hiện cái này lên thanh Tab */}
      
      <Tabs.Screen name="modal" options={{ href: null }} />
      <Tabs.Screen name="supabaseConfig" options={{ href: null }} />
      <Tabs.Screen name="context/ThemeContext" options={{ href: null }} />
      <Tabs.Screen name="(tabs)" options={{ href: null }} />
      
    </Tabs>
  );
}

export default function Layout() {
  return (
    <ThemeProvider>
      <TabLayoutInner />
    </ThemeProvider>
  );
}