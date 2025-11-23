import React, { useState } from 'react';
import { StyleSheet, Text, View, Button } from 'react-native';

export default function HomeScreen() {
  const [text, setText] = useState('Chưa bấm gì cả');

  return (
    <View style={styles.container}>
      <Text style={styles.title}>APP CỦA ĐẠI CA</Text>
      <Text style={styles.message}>{text}</Text>
      
      <View style={{ marginTop: 20 }}>
        <Button title="Bấm vào đây" onPress={() => setText('Đại ca đã bấm nút!')} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff', alignItems: 'center', justifyContent: 'center' },
  title: { fontSize: 24, fontWeight: 'bold', marginBottom: 20 },
  message: { fontSize: 18, color: 'blue' }
});