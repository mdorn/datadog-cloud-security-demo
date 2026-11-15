package demo;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import org.apache.commons.text.WordUtils;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

/** Logs a heartbeat once a minute. Opens no ports and reads no input. */
public final class Heartbeat {
    private static final Logger LOG = LogManager.getLogger(Heartbeat.class);
    private static final ObjectMapper JSON = new ObjectMapper();

    private Heartbeat() {}

    public static void main(String[] args) throws Exception {
        long beat = 0;
        while (true) {
            Map<String, Object> event = new LinkedHashMap<>();
            event.put("event", WordUtils.capitalize("heartbeat"));
            event.put("beat", ++beat);
            event.put("ts", Instant.now().toString());
            LOG.info(JSON.writeValueAsString(event));
            Thread.sleep(60_000L);
        }
    }
}
