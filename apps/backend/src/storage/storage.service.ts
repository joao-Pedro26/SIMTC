import { Injectable } from '@nestjs/common';
import { createClient } from '@supabase/supabase-js';

@Injectable()
export class StorageService {
  private readonly supabase = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_KEY!,
  );

  async upload(bucket: string, path: string, buffer: Buffer, contentType: string): Promise<string> {
    const { error } = await this.supabase.storage
      .from(bucket)
      .upload(path, buffer, { contentType, upsert: true });

    if (error) throw new Error(`Storage upload failed: ${error.message}`);

    const { data } = this.supabase.storage
      .from(bucket)
      .getPublicUrl(path);

    return data.publicUrl;
  }

  async download(bucket: string, path: string): Promise<Buffer> {
    const { data, error } = await this.supabase.storage.from(bucket).download(path);
    if (error) throw new Error(`Storage download failed: ${error.message}`);
    return Buffer.from(await data.arrayBuffer());
  }

  async delete(bucket: string, path: string): Promise<void> {
    await this.supabase.storage.from(bucket).remove([path]);
  }

  async getSignedUrl(bucket: string, path: string, expiresIn = 3600): Promise<string> {
    const { data, error } = await this.supabase.storage
      .from(bucket)
      .createSignedUrl(path, expiresIn);
    if (error) throw new Error(`Storage signed URL failed: ${error.message}`);
    return data.signedUrl;
  }
}
