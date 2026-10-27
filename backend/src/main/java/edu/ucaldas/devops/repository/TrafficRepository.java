package edu.ucaldas.devops.repository;
import edu.ucaldas.devops.model.TrafficIncident;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.List;
public interface TrafficRepository extends JpaRepository<TrafficIncident, Long> {
    List<TrafficIncident> findByRecordDateOrderByRecordTimeDesc(LocalDate recordDate);
}
