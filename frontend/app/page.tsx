"use client";

import { useEffect, useState } from 'react';
import { BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';

interface Analytics {
  summary: {
    total_records: number;
    total_sources: number;
    oldest_record?: string;
    newest_record?: string;
  };
  by_source: Record<string, number>;
  timeline: Array<{ date: string; count: number }>;
}

export default function Dashboard() {
  const [analytics, setAnalytics] = useState<Analytics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const API_URL = process.env.NEXT_PUBLIC_API_URL || '';

  useEffect(() => {
    fetchAnalytics();
  }, []);

  const fetchAnalytics = async () => {
    try {
      const response = await fetch(`${API_URL}/analytics`);
      if (!response.ok) throw new Error('Failed to fetch analytics');
      const data = await response.json();
      setAnalytics(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-xl">Loading analytics...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
        <p className="font-bold">Error</p>
        <p>{error}</p>
        <p className="text-sm mt-2">Make sure the API URL is configured: {API_URL || 'Not set'}</p>
      </div>
    );
  }

  if (!analytics) return null;

  const sourceData = Object.entries(analytics.by_source).map(([name, value]) => ({
    name,
    count: value
  }));

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-4xl font-bold mb-2">Dashboard</h1>
        <p className="text-gray-600">Real-time data pipeline analytics</p>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-blue-50 p-6 rounded-lg shadow">
          <div className="text-sm text-gray-600 mb-1">Total Records</div>
          <div className="text-3xl font-bold text-blue-600">
            {analytics.summary.total_records}
          </div>
        </div>
        <div className="bg-green-50 p-6 rounded-lg shadow">
          <div className="text-sm text-gray-600 mb-1">Data Sources</div>
          <div className="text-3xl font-bold text-green-600">
            {analytics.summary.total_sources}
          </div>
        </div>
        <div className="bg-purple-50 p-6 rounded-lg shadow">
          <div className="text-sm text-gray-600 mb-1">Oldest Record</div>
          <div className="text-sm font-semibold text-purple-600">
            {analytics.summary.oldest_record ? new Date(analytics.summary.oldest_record).toLocaleDateString() : 'N/A'}
          </div>
        </div>
        <div className="bg-orange-50 p-6 rounded-lg shadow">
          <div className="text-sm text-gray-600 mb-1">Latest Record</div>
          <div className="text-sm font-semibold text-orange-600">
            {analytics.summary.newest_record ? new Date(analytics.summary.newest_record).toLocaleDateString() : 'N/A'}
          </div>
        </div>
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-xl font-bold mb-4">Records by Source</h2>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={sourceData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="name" />
              <YAxis />
              <Tooltip />
              <Legend />
              <Bar dataKey="count" fill="#3b82f6" />
            </BarChart>
          </ResponsiveContainer>
        </div>

        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-xl font-bold mb-4">Ingestion Timeline</h2>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={analytics.timeline}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="date" />
              <YAxis />
              <Tooltip />
              <Legend />
              <Line type="monotone" dataKey="count" stroke="#10b981" strokeWidth={2} />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="bg-gray-50 p-6 rounded-lg">
        <h2 className="text-xl font-bold mb-4">Quick Actions</h2>
        <div className="flex gap-4">
          <a 
            href="/records" 
            className="bg-blue-600 text-white px-6 py-2 rounded hover:bg-blue-700 transition"
          >
            View All Records
          </a>
          <button 
            onClick={fetchAnalytics}
            className="bg-gray-600 text-white px-6 py-2 rounded hover:bg-gray-700 transition"
          >
            Refresh Data
          </button>
        </div>
      </div>
    </div>
  );
}

