package weblink._internal;
import haxe.MainLoop;
import haxe.io.Bytes;
import haxe.http.HttpMethod;
import sys.net.Host;
import weblink._internal.Socket;

class Server extends SocketServer
{
    var sockets:Array<Socket>;
    var parent:Weblink;
    var running:Bool = true;
    var loop:hl.uv.Loop;
    public function new(port:Int,parent:Weblink)
    {
        sockets = [];
        loop = hl.uv.Loop.getDefault();
        super(loop);
        bind(new Host("0.0.0.0"),port);
        noDelay(true);
        listen(100,function()
        {
            var stream = accept();
            var socket:Socket = cast stream;
            var request:Request = null;
            stream.readStart(function(data:Bytes)
            {
                if (data == null)
                {
                    sockets.remove(socket);
                    stream.close();
                    return;
                }
                if (request != null && request.method == Post)
                {
                    @:privateAccess var length = request.length - request.pos < data.length ? request.length - request.pos : data.length;
                    @:privateAccess request.data.blit(request.pos,data,0,length);
                    @:privateAccess request.pos += data.length;
                    @:privateAccess if (request.pos >= request.length)
                    {
                        complete(request,socket);
                        request = null;
                    }
                    return;
                }
                var lines = data.toString().split("\r\n");
                //go through lines
                @:privateAccess request = new Request(lines);
                if (request.method != Post) complete(request,socket);
            });
            sockets.push(socket);
        });
        this.parent = parent;
    }
    private inline function complete(request:Request,socket:Socket)
    {
        @:privateAccess var response = request.response(this,socket);
        switch (request.method)
        {
            case Get: @:privateAccess parent._getEvent(request,response);
            case Post: @:privateAccess parent._postEvent(request,response);
            case Head: @:privateAccess parent._headEvent(request,response);
            default: trace('Method ${request.method} Not supported yet');
        }
    }
    public function update()
    {
        while (running)
        {
            @:privateAccess MainLoop.tick(); //for timers
            loop.run(NoWait);
        }
    }
    public inline function closeSocket(socket:Socket)
    {
        sockets.remove(socket);
        socket.close();
    }
    override function close(#if (hl && !nolibuv) ?callb:() -> Void #end) 
    {
        //remove sockets array as well
        for (socket in sockets)
        {
            socket.close();
        }
        sockets = [];
        running = false;
        #if (hl && !nolibuv)
        loop.stop();
        #end
        super.close();
    }
}