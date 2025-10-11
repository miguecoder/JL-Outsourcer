"use client";

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

interface Record {
  id: string;
  source: string;
  captured_at: string;
  fingerprint: string;
  processed_at?: string;
  title?: string;
  name?: string;
  email?: string;
}

export default function RecordsPage() {
  const [records, setRecords] = useState<Record[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [sourceFilter, setSourceFilter] = useState<string>('all');
  const [sources, setSources] = useState<string[]>([]);
  const router = useRouter();

  const API_URL = process.env.NEXT_PUBLIC_API_URL || '';

  useEffect(() => {
    fetchRecords();
  }, [sourceFilter]);

  const fetchRecords = async () => {
    try {
      setLoading(true);
      const url = sourceFilter === 'all' 
        ? `${API_URL}/records?limit=50`
        : `${API_URL}/records?source=${sourceFilter}&limit=50`;
      
      const response = await fetch(url);
      if (!response.ok) throw new Error('Failed to fetch records');
      
      const data = await response.json();
      setRecords(data.records || []);
      
      // Extract unique sources
      const uniqueSources = Array.from(new Set(data.records.map((r: Record) => r.source)));
      setSources(uniqueSources as string[]);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-xl">Loading records...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
        <p className="font-bold">Error</p>
        <p>{error}</p>
        <p className="text-sm mt-2">API URL: {API_URL || 'Not set'}</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-4xl font-bold mb-2">Records</h1>
          <p className="text-gray-600">Browse all ingested and processed data</p>
        </div>
        <button 
          onClick={fetchRecords}
          className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
        >
          Refresh
        </button>
      </div>

      {/* Filters */}
      <div className="bg-white p-4 rounded-lg shadow">
        <div className="flex items-center gap-4">
          <label className="font-semibold">Filter by Source:</label>
          <select 
            value={sourceFilter}
            onChange={(e) => setSourceFilter(e.target.value)}
            className="border border-gray-300 rounded px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="all">All Sources</option>
            {sources.map(source => (
              <option key={source} value={source}>{source}</option>
            ))}
          </select>
          <span className="text-gray-600">
            {records.length} records found
          </span>
        </div>
      </div>

      {/* Records Table */}
      <div className="bg-white rounded-lg shadow overflow-hidden">
        <table className="min-w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                ID
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Source
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Data
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Captured At
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {records.map((record) => (
              <tr key={record.id} className="hover:bg-gray-50">
                <td className="px-6 py-4 whitespace-nowrap text-sm font-mono text-gray-900">
                  {record.id.substring(0, 20)}...
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                    record.source === 'jsonplaceholder' 
                      ? 'bg-blue-100 text-blue-800'
                      : 'bg-green-100 text-green-800'
                  }`}>
                    {record.source}
                  </span>
                </td>
                <td className="px-6 py-4 text-sm text-gray-900">
                  {record.title && <div className="truncate w-48">{record.title}</div>}
                  {record.name && <div className="truncate w-48">{record.name}</div>}
                  {record.email && <div className="text-xs text-gray-500">{record.email}</div>}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {new Date(record.captured_at).toLocaleString()}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm">
                  <button
                    onClick={() => router.push(`/records/${record.id}`)}
                    className="text-blue-600 hover:text-blue-900 font-medium"
                  >
                    View Details
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {records.length === 0 && (
        <div className="text-center py-12 text-gray-500">
          No records found. Try changing the filter or check if data ingestion is running.
        </div>
      )}
    </div>
  );
}

