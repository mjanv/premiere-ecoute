// AIDEV-NOTE: TypeScript declarations for Phoenix Socket
declare module 'phoenix' {
  export class Socket {
    constructor(endpoint: string, opts?: any);
    connect(): void;
    disconnect(): void;
    onOpen(callback: () => void): void;
    onError(callback: (error: any) => void): void;
    onClose(callback: () => void): void;
    channel(topic: string, params?: any): Channel;
  }
  
  export class Channel {
    join(): ChannelJoin;
    leave(): void;
    push(event: string, payload?: any): void;
    on(event: string, callback: (payload: any) => void): void;
    onMessage: (event: string, payload: any, ref: any) => any;
    onError(callback: (payload: any) => void): void;
  }
  
  export interface ChannelJoin {
    receive(status: string, callback: (response: any) => void): ChannelJoin;
  }
}