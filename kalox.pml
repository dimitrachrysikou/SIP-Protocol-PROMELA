mtype = { 
    INVITE, TRYING100, RINGING180, OK200, ACK, 
    RTP, BYE, BYE_OK, REJECTED, BUSY 
};

/*Κανάλια Επικοινωνίας*/
chan AliceToDatalink = [4] of { mtype };
chan ProxyToDatalink = [4] of { mtype };
chan BobToDatalink   = [4] of { mtype };
chan DatalinkToAlice = [4] of { mtype };
chan DatalinkToProxy = [4] of { mtype };
chan DatalinkToBob   = [4] of { mtype };

#define MAX_RETRIES 3




/*ΔΙΕΡΓΑΣΙΑ ALICE*/
proctype Alice() {
    mtype msg;
    byte retries = 0;
    
    end_alice_idle:
    retries = 0;

    send_invite:
    progress_alice: 
    AliceToDatalink!INVITE;
    
    expect_response: do
    :: DatalinkToAlice?msg ->
        if
        :: msg == TRYING100 -> skip;   
        :: msg == RINGING180 -> skip;  
        :: msg == BUSY -> 
            printf("Alice: Bob is BUSY. Call failed.\n"); 
            goto end_alice_idle;
        :: msg == REJECTED -> 
            printf("Alice: Call REJECTED. Call failed.\n"); 
            goto end_alice_idle;
        :: msg == OK200 -> 
            printf("Alice: Connected! Sending ACK\n");
            goto call_established;
        fi
    :: timeout -> 
        if
        :: retries < MAX_RETRIES ->
            retries++;
            printf("Alice: Timeout! Retransmitting INVITE\n", retries);
            goto send_invite;
        :: else -> 
            printf("Alice: Max retries reached. Call aborted.\n");
            goto end_alice_idle;
        fi
    od;

    call_established:
    AliceToDatalink!ACK;
    AliceToDatalink!RTP;
    
    retries = 0;
    send_bye:
    AliceToDatalink!BYE;
    
    expect_bye_ok: do
    :: DatalinkToAlice?msg ->
        if
        :: msg == BYE_OK -> 
            printf("Alice: Received BYE_OK. Dialog closed smoothly.\n"); 
            goto end_alice_idle;
        :: msg == OK200 -> AliceToDatalink!ACK; 
        fi
    :: timeout ->
        if
        :: retries < MAX_RETRIES ->
            retries++;
            printf("Alice: Timeout waiting for BYE_OK.\n");
            goto send_bye;
        :: else ->
            printf("Alice: Max retries for BYE reached. Forcing close.\n");
            goto end_alice_idle;
        fi
    od;
}





/*ΔΙΕΡΓΑΣΙΑ PROXY*/
proctype Proxy() {
    mtype msg;
    byte retries = 0;
    
    end_proxy_idle: do
    :: DatalinkToProxy?msg ->
        if
        :: msg == INVITE -> 
            ProxyToDatalink!TRYING100; 
            retries = 0; 
            goto forward_invite;
        fi
    od;

    forward_invite:
    progress_proxy: 
    ProxyToDatalink!INVITE;

    forward_responses: do
    :: DatalinkToProxy?msg ->
        if
        :: msg == RINGING180 || msg == OK200 || msg == BUSY || msg == REJECTED -> ProxyToDatalink!msg; 
            if
            :: msg == BUSY || msg == REJECTED || msg == OK200 -> goto end_proxy_idle; 
            :: msg == RINGING180 -> skip;
            fi
        fi
    :: timeout -> 
        if
        :: retries < MAX_RETRIES ->
            retries++;
            printf("Proxy: Timeout waiting for Bob. Resending INVITE to Bob\n");
            ProxyToDatalink!INVITE;
        :: else -> 
            printf("Proxy: Bob is unreachable. Informing Alice (BUSY)\n");
            ProxyToDatalink!BUSY;
            goto end_proxy_idle;
        fi
    od;
}





/*ΔΙΕΡΓΑΣΙΑ BOB*/
proctype Bob() {
    mtype msg;
    
    end_bob_idle: do
    :: DatalinkToBob?msg ->
        if
        :: msg == INVITE -> goto handle_call;
        fi
    od;

    handle_call:
    progress_bob: 
    if
    :: BobToDatalink!BUSY; goto end_bob_idle; 
    :: BobToDatalink!REJECTED; goto end_bob_idle; 
    :: BobToDatalink!RINGING180 -> goto accept_call;
    fi;

    accept_call:
    send_ok:
    BobToDatalink!OK200;

    end_wait_ack: do
    :: DatalinkToBob?msg ->
        if
        :: msg == ACK -> goto end_active_call;
        :: msg == INVITE -> goto send_ok; 
        :: msg == RTP -> goto end_active_call; 
        :: msg == BYE -> BobToDatalink!BYE_OK; goto end_bob_idle;
        fi
    :: timeout ->
        printf("Bob: Timeout waiting for ACK. Retransmitting OK200\n");
        goto send_ok;
    od;

    end_active_call: do
    :: DatalinkToBob?msg ->
        if
        :: msg == RTP -> printf("Bob: Processing incoming RTP audio stream\n");
        :: msg == BYE -> 
            BobToDatalink!BYE_OK; 
            printf("Bob: Received BYE. Sent BYE_OK. Call ended.\n");
            goto end_bob_idle;
        :: msg == ACK -> skip; 
        fi
    od;
}



/*ΔΙΕΡΓΑΣΙΑ DATALINK ΑΠΩΛΕΙΕΣ*/
proctype datalink() {
    mtype msg;
         
    end_datalink_loop: do
    :: AliceToDatalink?msg ->
        if
        :: msg == INVITE -> 
            if :: DatalinkToProxy!msg; :: skip; fi; 
        :: msg == ACK || msg == RTP || msg == BYE -> 
            if :: DatalinkToBob!msg; :: skip; fi;
        fi;
            
    :: ProxyToDatalink?msg ->
        if
        :: msg == TRYING100 || msg == RINGING180 || msg == OK200 || msg == BUSY || msg == REJECTED ->
            if :: DatalinkToAlice!msg; :: skip; fi;
        :: msg == INVITE -> if :: DatalinkToBob!msg; :: skip; fi;
        fi;

    :: BobToDatalink?msg ->
        if
        :: msg == BUSY || msg == REJECTED || msg == RINGING180 || msg == OK200 ->
            if :: DatalinkToProxy!msg; :: skip; fi;
        :: msg == BYE_OK || msg == RTP -> if :: DatalinkToAlice!msg; :: skip; fi;
        fi;
    od;
}

/*Αρχικοποίηση Συστήματος*/
init {
    atomic {
        run datalink();
        run Alice();
        run Proxy();
        run Bob();
    }
}
